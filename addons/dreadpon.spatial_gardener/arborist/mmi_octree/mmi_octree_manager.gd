@tool
extends Resource


#-------------------------------------------------------------------------------
# Handles higher-level management of OctreeNode objects
# Creation of new trees (octree roots), some of the growing/collapsing functionality
# Exposes lifecycle management to outside programs
# And passes changes made to members/plants to its OctreeNodes
#-------------------------------------------------------------------------------


const MMIOctreeNode = preload("mmi_octree_node.gd")
const FunLib = preload("../../utility/fun_lib.gd")
const DponDebugDraw = preload("../../utility/debug_draw.gd")
const GreenhouseLODVariant = preload("../../greenhouse/greenhouse_LOD_variant.gd")


@export var root_octree_node: Resource = null
@export var LOD_variants : Array[GreenhouseLODVariant] : set = set_LOD_variants
@export var LOD_max_distance:float
@export var LOD_kill_distance:float

var add_placeforms_queue:Array
var remove_placeforms_queue:Array
var set_placeforms_queue:Array


signal req_debug_redraw




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init():
	resource_local_to_scene = true
	set_meta("class", "MMIOctreeManager")
	resource_name = "MMIOctreeManager"
	
	if LOD_variants == null || LOD_variants.is_empty():
		LOD_variants = []
	add_placeforms_queue = []
	remove_placeforms_queue = []
	set_placeforms_queue = []


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(root_octree_node):
			# Avoid memory leaks when OctreeNode leaks MMI nodes and spawned spatials
			root_octree_node.prepare_for_removal()


# Duplictes the octree structure
func duplicate_tree():
	var copy = duplicate(false)
	copy.root_octree_node = copy.root_octree_node.duplicate_tree()
	copy.connect_node(copy.root_octree_node)
	LOD_variants = LOD_variants.duplicate()
	return copy


func deep_copy():
	var copy = duplicate(false)
	copy.root_octree_node = copy.root_octree_node.deep_copy()
	copy.connect_node(copy.root_octree_node)
	LOD_variants = LOD_variants.duplicate()
	return copy


# Restore any states that might be broken after loading OctreeNode objects
func restore_after_load(__MMI_container:Node3D):
	if is_instance_valid(root_octree_node):
		root_octree_node.restore_after_load(__MMI_container, LOD_variants)
		connect_node(root_octree_node)
		request_debug_redraw()


func init_octree(members_per_node:int, root_extent:float, center:Vector3 = Vector3.ZERO, MMI_container:Node3D = null, min_leaf_extent:float = 0.0):
	root_octree_node = MMIOctreeNode.new(null, members_per_node, root_extent, center, -1, min_leaf_extent, MMI_container, LOD_variants)
	connect_node(root_octree_node)
	request_debug_redraw()


func connect_node(octree_node:MMIOctreeNode):
	assert(octree_node)
	FunLib.ensure_signal(octree_node.placeforms_rejected, grow_to_members)
	FunLib.ensure_signal(octree_node.collapse_self_possible, collapse_root)
	FunLib.ensure_signal(octree_node.req_debug_redraw, request_debug_redraw)


func disconnect_node(octree_node:MMIOctreeNode):
	assert(octree_node)
	octree_node.placeforms_rejected.disconnect(grow_to_members)
	octree_node.collapse_self_possible.disconnect(collapse_root)
	octree_node.req_debug_redraw.disconnect(request_debug_redraw)


func prepare_for_removal():
	if root_octree_node:
		root_octree_node.prepare_for_removal()


# Free anything that might incur a circular reference or a memory leak
# Anything that is @export'ed is NOT touched here
# We count on Godot's own systems to handle that in whatever way works best
# TODO: this is very similar to prepare_for_removal(), need to determine how best to combine the two
#		will need to happen around v2.0.0, since it's a very risky change
func free_refs():
	if !root_octree_node: return
	root_octree_node.free_refs()




#-------------------------------------------------------------------------------
# Restructuring
#-------------------------------------------------------------------------------


# Rebuild the tree with new extent and member limitations
# The resulting octree node layout depends on the order of members in which they are added
# Hence the layout may difer if the members are the same, but belong to different nodes each time
# I.e. it can't be predicted with members_per_node and min_leaf_extent alone, for now it is (as far as it matters) non-deterministic
func rebuild_octree(members_per_node:int, min_leaf_extent:float):
	assert(root_octree_node)
	var all_placeforms:Array = []
	root_octree_node.get_nested_placeforms(all_placeforms)
	root_octree_node.prepare_for_removal()
	
	init_octree(members_per_node, min_leaf_extent, Vector3.ZERO,
		root_octree_node.MMI_container, min_leaf_extent)

	if !all_placeforms.is_empty():
		queue_placeforms_add_bulk(all_placeforms)
		process_queues()
	request_debug_redraw()
	
	debug_manual_root_logger("rebuilt root")


# Recenter a tree and shrink to fit it's current members
func recenter_octree():
	assert(root_octree_node)
	
	var last_root:MMIOctreeNode = root_octree_node
	var all_placeforms:Array = []
	last_root.get_nested_placeforms(all_placeforms)
	last_root.prepare_for_removal()
	
	var new_center:Vector3 = Vector3.ZERO
	var new_extent:float = last_root.min_leaf_extent
	
	if all_placeforms.size() > 0:
		for placeform in all_placeforms:
			new_center += placeform[0]
		new_center /= all_placeforms.size()
		
		for placeform in all_placeforms:
			var delta_pos = (placeform[0] - new_center).abs()
			new_extent = max(new_extent, max(delta_pos.x, max(delta_pos.y, delta_pos.z)))
	
	init_octree(last_root.max_members, new_extent, new_center,
		root_octree_node.MMI_container, last_root.min_leaf_extent)

	if !all_placeforms.is_empty():
		queue_placeforms_add_bulk(all_placeforms)
		process_queues()
	request_debug_redraw()
	
	debug_manual_root_logger("recentered root")


# Grow the tree to fit any members outside it's current bounds (by creating a whole new layer on top)
func grow_to_members(placeforms:Array):
	assert(root_octree_node) # 'root_octree_node' is not initialized
	assert(placeforms.size() > 0) # 'placeforms' is empty
	
	var target_point = placeforms[0][0]
	
	var last_root:MMIOctreeNode = root_octree_node
	disconnect_node(last_root)
	var last_octant = last_root._map_point_to_opposite_octant(target_point)
	var new_center = last_root.center_pos - last_root._get_octant_center_offset(last_octant)
	
	init_octree(last_root.max_members, last_root.extent * 2.0, new_center, last_root.MMI_container, last_root.min_leaf_extent)
	debug_manual_root_logger("grew to members")
	root_octree_node.adopt_child(last_root, last_octant)
	var root_copy = root_octree_node
	
	add_placeforms(placeforms)
	root_copy.try_collapse_children(0)


# Make one of the root's children the new root
func collapse_root(new_root_octant):
	assert(root_octree_node) # 'root_octree_node' is not initialized
	
	var last_root:MMIOctreeNode = root_octree_node
	disconnect_node(last_root)
	
	root_octree_node = last_root.child_nodes[new_root_octant]
	last_root.collapse_self(new_root_octant)
	
	connect_node(root_octree_node)
	root_octree_node.safe_init_root()
	root_octree_node.try_collapse_self(0)


func get_all_placeforms(target_array: Array = []):
	if root_octree_node:
		return root_octree_node.get_nested_placeforms(target_array)




#-------------------------------------------------------------------------------
# Processing members
#-------------------------------------------------------------------------------


# Queue changes for bulk processing
func queue_placeforms_add(placeform):
	add_placeforms_queue.append(placeform)


func queue_placeforms_add_bulk(placeforms: Array):
	add_placeforms_queue.append_array(placeforms)


# Queue changes for bulk processing
func queue_placeforms_remove(placeform):
	remove_placeforms_queue.append(placeform)


# Queue changes for bulk processing
func queue_placeforms_set(change):
	set_placeforms_queue.append(change)


# Bulk process the queues
func process_queues():
	assert(root_octree_node) # 'root_octree_node' is not initialized
	var affected_addressed := []
	
	if !add_placeforms_queue.is_empty():
		add_placeforms(add_placeforms_queue)
	if !remove_placeforms_queue.is_empty():
		remove_placeforms(remove_placeforms_queue)
	if !set_placeforms_queue.is_empty():
		set_placeforms(set_placeforms_queue)
	
	add_placeforms_queue = []
	remove_placeforms_queue = []
	set_placeforms_queue = []
	
	# Make sure we update LODs even for nodes at max LOD index
	# Since we changed their children most likely
	set_LODs_to_active_index()


func add_placeforms(placeforms:Array):
	assert(root_octree_node) # 'root_octree_node' is not initialized
	assert(placeforms.size() > 0) # 'placeforms' is empty
	
	root_octree_node.add_members(placeforms)
	root_octree_node.MMI_refresh_instance_placements_recursive()
	request_debug_redraw()


func remove_placeforms(placeforms:Array):
	assert(root_octree_node) # 'root_octree_node' is not initialized
	assert(placeforms.size() > 0) # 'placeforms' is empty
	
	root_octree_node.remove_members(placeforms)
	root_octree_node.process_collapse_children()
	root_octree_node.process_collapse_self()
	root_octree_node.MMI_refresh_instance_placements_recursive()
	request_debug_redraw()
	
#	if root_octree_node.child_nodes.size() <= 0 && root_octree_node.members.size() <= 0:
#		reset_root_size()


func set_placeforms(changes:Array):
	assert(root_octree_node) # 'root_octree_node' is not initialized
	assert(changes.size() > 0) # 'changes' is empty
	
	root_octree_node.set_members(changes)




#-------------------------------------------------------------------------------
# LOD management
#-------------------------------------------------------------------------------


func set_LOD_variants(val):
	LOD_variants.resize(0)
	for LOD_variant in val:
		LOD_variants.append(LOD_variant)


# Up-to-date LOD variants of an OctreeNode
func insert_LOD_variant(variant, index:int):
	LOD_variants.insert(index, variant)


# Up-to-date LOD variants of an OctreeNode
func remove_LOD_variant(index:int):
	LOD_variants.remove_at(index)


# Up-to-date LOD variants of an OctreeNode
func set_LOD_variant(variant, index:int):
	LOD_variants[index] = variant


# Up-to-date LOD variants of an OctreeNode
func set_LOD_variant_spawned_spatial(variant, index:int):
	# No need to manually set spawned_spatial, it will be inherited from parent resource
	
	# /\ I don't quite remember what this comment meant, but since LOD_Variants are shared
	# It seems to imply that the line below in not neccessary
	# So I commented it out for now
#	LOD_variants[index].spawned_spatial = variant
	pass


func reset_member_spatials():
	root_octree_node.reset_member_spatials()


# Make sure LODs in OctreeNodes correspond to their active_LOD_index
# This is the preffered way to 'refresh' MMIs inside OctreeNodes
func set_LODs_to_active_index():
	root_octree_node.set_LODs_to_active_index()


# Update LODs in OctreeNodes depending on their distance to camera
func update_LODs(camera_pos:Vector3, container_transform:Transform3D):
	camera_pos = container_transform.affine_inverse() * camera_pos
	root_octree_node.update_LODs(camera_pos, LOD_max_distance, LOD_kill_distance)


func update_LODs_no_camera():
	root_octree_node.update_LODs(Vector3.ZERO, -1.0, -1.0)




#-------------------------------------------------------------------------------
# Debug
#-------------------------------------------------------------------------------


# A callback to request a debug redraw
func request_debug_redraw():
	req_debug_redraw.emit()


# Manually trigger a Logger message when an OctreeNode doesn't know an important action happened
func debug_manual_root_logger(message:String):
	root_octree_node.print_address(message)
