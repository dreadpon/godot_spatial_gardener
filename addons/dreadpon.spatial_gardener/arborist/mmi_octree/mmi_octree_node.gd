# TODO: it's a mess
#		need to stricly define places where we
#			load from disk
#			switch container/mmi on and off (in response to LOD change or member addition/removal)
#			actually add new members
#			refreshing existing members on LOD change
#			TBA after looking at the code again

@tool
extends Resource


#-------------------------------------------------------------------------------
# Used to store placements and reference an MMI that represents them
# Meant to speed up iteration and split LOD management into faster, smaller and more manageable chunks
#-------------------------------------------------------------------------------

# Parent OctreeNodes do not have members of their own and delegate them to their children
# That is (in part) because no one member can exist in more than one OctreeNode
# Since member represents a position and treated as if it had no volume


const FunLib = preload("../../utility/fun_lib.gd")
const Logger = preload("../../utility/logger.gd")
const Placeform = preload("../placeform.gd")
const OctreeLeaf = preload("octree_leaf.gd")
const Greenhouse_LODVariant = preload("../../greenhouse/greenhouse_LOD_variant.gd")

# A dummy mesh, since in Godot 4.0 multimesh breaks if it has transforms set but no mesh assigned
# This is used when there's no "actual" mesh
var DUMMY_MMI_MESH: Mesh = ArrayMesh.new()

# An array for looking up placements conviniently
# Since a member placement is practically it's ID
# TODO: this can be rewritten to use PackedFloat32Array to reduce scene filesize
#		but that would require us to write a search function in C++ (used when removing members from nodes)
#		as GDScript is too slow for this bruteforce method
@export var member_placeforms: Array = []

@export var child_nodes:Array = [] # (Array, Resource)
@export var max_members:int
@export var min_leaf_extent:float

@export var octant:int
@export var is_leaf:bool

@export var center_pos:Vector3
@export var extent:float
@export var bounds:AABB
@export var max_bounds_to_center_dist:float
@export var min_bounds_to_center_dist:float

@export var active_LOD_index:int = -1

var parent:Resource
var gardener_root: Node3D
var leaf: OctreeLeaf = OctreeLeaf.new()
var shared_LOD_variants:Array = []

var logger = null


signal placeforms_rejected(new_placeforms) 	# (new_placeforms: Array<Array>)
signal collapse_self_possible(octant)	# (octant: int)
signal req_debug_redraw()




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


# Last two variables will be used only if there was no parent passed
func _init(__parent:Resource = null, __max_members:int = 0, __extent:float = 0.0, __center_pos:Vector3 = Vector3.ZERO,
	__octant:int = -1, __min_leaf_extent:float = 0.0, __gardener_root:Node3D = null, __LOD_variants:Array = []):
	
	resource_local_to_scene = true
	set_meta("class", "MMIOctreeNode")
	resource_name = "MMIOctreeNode"
	
	logger = Logger.get_for(self)
	
	max_members = __max_members
	child_nodes.clear()
	reset_placeforms()
	

	# This differentiation helps to keep common functionality when reparenting/collapsing nodes
	if __parent:
		safe_inherit(__parent)
		# Separation below helps not to overwrite anything by mistake
		center_pos = _get_octant_center_offset(__octant)
		center_pos += parent.center_pos
		octant = __octant
	else:
		safe_init_root()
		# Separation below helps not to overwrite anything by mistake
		extent = __extent
		center_pos = __center_pos
		min_leaf_extent = __min_leaf_extent
		gardener_root = __gardener_root
		shared_LOD_variants = __LOD_variants

	#print("init")
	# NOTE: intentionally after safe_inherit() so that we always have gardener_root available	
	leaf.set_octree_node(self)

	set_is_leaf(true)
	max_bounds_to_center_dist = sqrt(pow(extent, 2) * 3)
	min_bounds_to_center_dist = extent
	bounds = AABB(center_pos - Vector3(extent, extent, extent), Vector3(extent, extent, extent) * 2.0)
	
	print_address("", "initialized")


# Duplictes the octree structure
func duplicate_tree():
	var copy = self.duplicate()
	copy.member_placeforms = member_placeforms.duplicate(true)
	copy.child_nodes = []
	for child_node in child_nodes:
		var child_copy = child_node.duplicate_tree()
		child_copy.parent = copy
		copy.child_nodes.append(child_copy)
	copy.leaf = leaf.clone(copy)
	return copy


# Inherit inheritable properties of a parent
func safe_inherit(__parent):
	parent = __parent
	extent = parent.extent * 0.5
	min_leaf_extent = parent.min_leaf_extent
	gardener_root = parent.gardener_root
	shared_LOD_variants = parent.shared_LOD_variants


# Reset properties, that represent parent inheritance (but otherwise serve no purpose)
func safe_init_root():
	parent = null
	octant = -1


# Restore any states that might be broken after loading this node
func restore_after_load(__gardener_root:Node3D, LOD_variants:Array):
	gardener_root = __gardener_root
	shared_LOD_variants = LOD_variants
	
	if shared_LOD_variants.size() <= active_LOD_index:
		_set_active_LOD_index(shared_LOD_variants.size() - 1, true)

	if leaf == null:
		leaf = OctreeLeaf.new()
	#print("restore")
	# No need to explicitly call on_active_lod_index_changed, since it's accounted for in restore_after_load
	leaf.restore_after_load() 

	for child in child_nodes:
		child.parent = self
		child.restore_after_load(__gardener_root, LOD_variants)
	
	print_address("", "restored after load")


func propagate_transform(global_transform: Transform3D):
	leaf.on_root_transform_changed(global_transform)
	for child in child_nodes:
		child.propagate_transform(global_transform)


# Mark node as having or not having any members
# If yes, also create an MMI
func set_is_leaf(val):
	is_leaf = val
	
	# NOTE: this was previously under 'elif' check. Look out for unexpected behavior
	#active_LOD_index = -1

	leaf.on_is_leaf_changed(is_leaf)
	#leaf.on_active_lod_index_changed()


# Cleanup this this node before deletion
# TODO: find out if I can clear the member array here as well
func free_octree_relationship_refs():
	print_address("", "prepare for removal")
	
	# Avoid circular reference so that RefCount can properly free objects
	parent = null
	for child in child_nodes:
		child.free_octree_relationship_refs()
	child_nodes.clear()
	
	set_is_leaf(false)


# Free anything that might incur a circular reference or a memory leak
# Anything that is @export'ed is NOT touched here
# We count on Godot's own systems to handle that in whatever way works best
# TODO: this is very similar to prepare_for_removal(), need to determine how best to combine the two
#		will need to happen around v2.0.0, since it's a very risky change
func free_circular_refs():
	for child in child_nodes:
		child.free_circular_refs()
	if is_instance_valid(leaf):
		leaf.free_circular_refs()

	parent = null
	gardener_root = null
	leaf = null


func restore_circular_refs(p_parent: Resource, p_gardener_root: Node3D):
	if p_parent:
		safe_inherit(p_parent)
	gardener_root = p_gardener_root
	if !is_instance_valid(leaf):
		leaf = OctreeLeaf.new()

	for child in child_nodes:
		child.restore_circular_refs(self, p_gardener_root)
	leaf.restore_circular_refs(self)




#-------------------------------------------------------------------------------
# LOD management
#-------------------------------------------------------------------------------


# Make sure LOD corresponds to the active_LOD_index
func set_LODs_to_active_index():
	if is_leaf:
		if shared_LOD_variants.size() <= active_LOD_index:
			_set_active_LOD_index(shared_LOD_variants.size() - 1)
	else:
		for child in child_nodes:
			child.set_LODs_to_active_index()


# Update LOD depending on node's distance to camera
func update_LODs(camera_pos:Vector3, LOD_max_distance:float, LOD_kill_distance:float):
	# If we don't have any LOD variants, abort the entire update process
	# We assume mesh and spatials are reset on shared_LOD_variants change using set_LODs_to_active_index() call from an arborist
	#print(self.leaf, " update_LODs")
	if shared_LOD_variants.is_empty(): return
	
	var dist_to_node_center := (center_pos - camera_pos).length()
	
	var max_LOD_dist := LOD_max_distance + min_bounds_to_center_dist #max_bounds_to_center_dist
	var max_kill_dist := LOD_kill_distance + min_bounds_to_center_dist #max_bounds_to_center_dist
	var dist_to_node_center_bounds_estimate: float = clamp(dist_to_node_center - max_bounds_to_center_dist, 0.0, INF)
	
	#print(
		#LOD_kill_distance, " + ", min_bounds_to_center_dist, " = ", max_kill_dist, "     ", 
		#dist_to_node_center, " - ", max_bounds_to_center_dist, " = ", dist_to_node_center_bounds_estimate)
	
	var skip_assignment := false
	var skip_children := false
	var max_LOD_index = shared_LOD_variants.size() - 1
	
	var outside_kill_treshold: bool = LOD_kill_distance >= 0.0 && dist_to_node_center_bounds_estimate >= max_kill_dist
	var inside_kill_treshold: bool = LOD_kill_distance >= 0.0 && dist_to_node_center_bounds_estimate < max_kill_dist
	var outside_max_treshold: bool = dist_to_node_center_bounds_estimate >= max_LOD_dist
	
	# If outside the kill threshold
	if outside_kill_treshold:
		# If haven't yet reset MMIs and spawned spatials, reset them
		if active_LOD_index >= 0:
			_set_active_LOD_index(-1)
		# If up-to-date, skip assignment
		else:
			skip_children = true
		skip_assignment = true
	# If already at max LOD and outside of the max LOD threshold
	elif !inside_kill_treshold && active_LOD_index == max_LOD_index && outside_max_treshold:
		# Skip assignment
		skip_assignment = true
		skip_children = true
	
	if !skip_assignment:
		# We set LOD_index on both leaves/non-leaves to keep track of updated/not-updated parent nodes
		# To safely optimize them away using 'if' statements above
		assign_LOD_variant(max_LOD_index, LOD_max_distance, LOD_kill_distance, dist_to_node_center_bounds_estimate)
	
	if !skip_children:
		# Iterate over all children
		if !is_leaf:
			for child in child_nodes:
				child.update_LODs(camera_pos, LOD_max_distance, LOD_kill_distance)
	# Else we do nothing: this node and all it's children are up-to-date outside either max_LOD_index or LOD_kill_distance


# Check if camera is within range, calculate a LOD variant index and set it
func assign_LOD_variant(max_LOD_index:int, LOD_max_distance:float, LOD_kill_distance:float, dist_to_node_center_bounds_estimate:float):
	var LOD_index = max_LOD_index
	
	# Drop calculations if LOD_max_distance is zero - that means we use max_LOD_index by default (mostly because we can't divide by zero)
	if LOD_max_distance > 0:
		LOD_index = clamp(floor(dist_to_node_center_bounds_estimate / LOD_max_distance * max_LOD_index), 0, max_LOD_index)
	
	# Skip if already assigned this LOD_index and not marked as dirty
	if active_LOD_index == LOD_index: return
	
	_set_active_LOD_index(LOD_index)
	
	# We need to set active_LOD_index on both leaves/non-leaves
	# But non-leaves do not have an MMI and can't spawn spatials
	#if is_leaf:
		#print(MMI_multimesh)
		#leaf.on_active_lod_index_changed()


func _set_active_LOD_index(p_active_LOD_index: int, p_skip_leaf_update: bool = false):
	active_LOD_index = p_active_LOD_index
	if !p_skip_leaf_update:
		leaf.on_active_lod_index_changed()




#-------------------------------------------------------------------------------
# Member management
#-------------------------------------------------------------------------------


# Reset all arrays storing the member data
func reset_placeforms():
	member_placeforms.clear()
	leaf.on_reset_placeforms()


# Add new member data
func append_placeforms(p_placeforms: Array):
	member_placeforms.append_array(p_placeforms)
	leaf.on_appended_placeforms(p_placeforms)	


# Remove member data by index
func remove_placeform_at(idx: int):
	member_placeforms.remove_at(idx)
	leaf.on_removed_placeform_at(idx)


# Set member data by index
func set_placeform_at(idx:int, placeform: Array):
	member_placeforms[idx] = placeform
	leaf.on_set_placeform_at(idx, placeform)




# Add members to self, propagate them to children to request a growth from the OctreeManager
# This function is destructive to the passed array. Duplicate it if the original needs to stay intact
func add_members(new_placeforms:Array):
	# If we found any members outside this node - gather them up
	# And request a growth from OctreeManager to accommodate these members
	# Rejected members are put at the front since OctreeManager uses [0] to determine growth direction
	
	var rejected = reject_outside_placeforms(new_placeforms)
	if rejected.size() > 0:
		placeforms_rejected.emit(rejected + new_placeforms)
		# Further execution can lead to members being added to a collapsed node
		# (OctreeManager tries to collapse children when growing to members)
		# So we abort
		return []
	
	if new_placeforms.is_empty(): return []
	
	var mapped_placeforms = assign_octants_to_placeforms(new_placeforms)
	
	var members_changed := false
	if extent * 0.5 >= min_leaf_extent:
		if child_nodes.is_empty() && get_member_count() + new_placeforms.size() > max_members:
			_make_children()
			var self_mapped_placeforms = assign_octants_to_placeforms(member_placeforms)
			for octant in self_mapped_placeforms:
				_add_members_to_child(octant, self_mapped_placeforms[octant])
			reset_placeforms()
	
	if !child_nodes.is_empty():
		for octant in mapped_placeforms:
			_add_members_to_child(octant, mapped_placeforms[octant])
	else:
		members_changed = true
		append_placeforms(new_placeforms)

		if FunLib.get_setting_safe("dreadpons_spatial_gardener/debug/octree_log_lifecycle", false): 
			for placeform in new_placeforms:
				print_address("", "adding placeform " + Placeform.to_str(placeform))
	
	if members_changed && parent:
		parent._child_added_members(octant)


# Remove members from self, or children
# This function is destructive to the passed array. Duplicate it if the original needs to stay intact
# TODO: add proper bulk edit support same way as in add_members()
#		main obstacle is how growing/shrinking works and it's apparent incompatability 
#		with obvious/straightforward implementation of bulk edits
func remove_members(old_placeforms:Array):
	if old_placeforms.is_empty(): return
	
	# Presumably, it's ok to overwrite the members' octants
	# Since we WILL remove them and won't ever need to reference previous positions inside a node
	assign_octants_to_placeforms(old_placeforms)
	
	var members_changed := false
	for placeform in old_placeforms:
		if child_nodes.size() > 0:
			_remove_member_from_child(placeform)
		else:
			var found_placement_idx = member_placeforms.find(placeform)
			if found_placement_idx >= 0:
				remove_placeform_at(found_placement_idx)
				print_address("", "erased placeform " + Placeform.to_str(placeform))
				members_changed = true
	
	if members_changed && parent:
		parent._child_removed_members(octant)


# Update members' Transforms at given address
func set_members(changes:Array):
	# Mark this node as 'dirty' to make sure it gets update in the next update_LODs()
	#active_LOD_index = -1
	
	for change in changes:
		var octree_node = find_child_by_address(change.address)
		octree_node.set_placeform_at(change.index, change.placeform)


# Rejects members outside the bounds
func reject_outside_placeforms(new_placeforms:Array):
	if parent || new_placeforms.is_empty(): return []
	
	var rejected := []
	for i in range(new_placeforms.size() - 1, -1, -1):
		var placeform = new_placeforms[i]
		if !bounds.has_point(placeform[0]):
			rejected.append(placeform)
			new_placeforms.remove_at(i)
	
	return rejected


# Map members to octants within this node (i.e. place inside a 2x2x2 cube)
# It's mostly used to quick access the child node holding this member
func assign_octants_to_placeforms(new_placeforms: Array):
	# Map to and return a Dictionary, to support passing members in bulk to octants/child octree nodes
	var mapped_placeforms = {}
	for i in 8:
		mapped_placeforms[i] = []
	var octant = 0
	for placeform in new_placeforms:
		octant = _map_point_to_octant(placeform[0])
		placeform[3] = octant
		mapped_placeforms[octant].append(placeform)
	return mapped_placeforms


func _add_members_to_child(child_octant: int, placeforms: Array):
	child_nodes[child_octant].add_members(placeforms)


# TODO: bulk removal not supported yet
#		implement proper bulk removal of members
func _remove_member_from_child(old_placeform: Array):
	child_nodes[old_placeform[3]].remove_members([old_placeform])




#-------------------------------------------------------------------------------
# MMI and spawned spatial management
#-------------------------------------------------------------------------------


# # A workaround, since in Godot 4.0 multimesh breaks 
# # If it has transforms set but no mesh assigned or zero instances
# # With resource_local_to_scene set to true
# func validate_MMI_multimesh():
# 	if MMI:
# 		var valid_mesh = is_instance_valid(MMI_multimesh.mesh) && MMI_multimesh.mesh != DUMMY_MMI_MESH
# 		if valid_mesh && MMI_multimesh.instance_count > 0:
# 			if MMI.multimesh != MMI_multimesh:
# 				MMI.multimesh = MMI_multimesh
# 		elif MMI_multimesh.instance_count == 0:
# 			MMI_multimesh.mesh = null#DUMMY_MMI_MESH
# 		# elif MMI.multimesh != null:
# 		# 	MMI.multimesh = null


func get_member_transform(member_idx: int):
	return member_placeforms[member_idx][2]


# NOTE: this changed requires update_LODs() call; it will be called by Arborist next frame automatically
func on_lod_variant_inserted(index:int):
	if active_LOD_index >= index:
		leaf.on_preceeding_lod_variant_changed()
	for child in child_nodes:
		child.on_lod_variant_inserted(index)


# NOTE: this changed requires update_LODs() call; it will be called by Arborist next frame automatically
func on_lod_variant_removed(index:int):
	if active_LOD_index >= index:
		leaf.on_preceeding_lod_variant_changed()
	for child in child_nodes:
		child.on_lod_variant_removed(index)


func on_lod_variant_set(index:int):
	if active_LOD_index == index:
		leaf.on_preceeding_lod_variant_changed()
	for child in child_nodes:
		child.on_lod_variant_set(index)


func on_lod_variant_spatial_changed(index:int):
	if active_LOD_index == index:
		leaf.on_active_lod_variant_spatial_changed()
	for child in child_nodes:
		child.on_lod_variant_spatial_changed(index)


func on_lod_variant_mesh_changed(index:int):
	if active_LOD_index == index:
		leaf.on_active_lod_variant_mesh_changed()
	for child in child_nodes:
		child.on_lod_variant_mesh_changed(index)


func on_lod_variant_shadow_changed(index:int):
	if active_LOD_index == index:
		leaf.on_active_lod_variant_shadow_changed()
	for child in child_nodes:
		child.on_lod_variant_shadow_changed(index)




#-------------------------------------------------------------------------------
# Child nodes management
#-------------------------------------------------------------------------------


# Create 8 child nodes that represent a deeper layer of this tree
func _make_children():
	var self_class = get_script()
	for octant in range(0, 8):
		var child = self_class.new(self, max_members, 0.0, Vector3.ZERO, octant)
		child_nodes.append(child)
		# NOTE: line below is essential for properly initializing instances 
		#		when passing them down to newly created children
		child._set_active_LOD_index(active_LOD_index)
	set_is_leaf(false)
	#print(self, " _make_children")


# Adopt another OctreeNode as a child in a given octant
func adopt_child(child, octant:int):
	if child_nodes.is_empty():
		_make_children()
	
	child_nodes[octant].free_octree_relationship_refs()
	child_nodes[octant] = child
	child.octant = octant
	child.safe_inherit(self)
	print_address("", "adopted child " + str(child))


# Called when a child node got some members added
func _child_added_members(octant:int):
	pass


# Called when a child node got some members removed
func _child_removed_members(octant:int):
	pass


# Process all nodes in a tree and try to collapse their children
# NB Collapsing happens from deepest node upwards to topmost nodes
func process_collapse_children():
	for child in child_nodes:
		child.process_collapse_children()
	try_collapse_children(0)


# Process all nodes in a tree and try to collapse self
# NB Collapsing happens from topmost node downwards to deepest nodes
func process_collapse_self():
	try_collapse_self(0)
	for child in child_nodes:
		child.process_collapse_self()


# Try to collapse children if possible
func try_collapse_children(instigator_child:int):
	print_address("", "try to collapse children")
	var total_member_count := 0
	var can_collapse := true
	var reason:String
	
	# If no children - no collapsing
	if child_nodes.size() <= 0:
		can_collapse = false
		reason = "child_nodes.size() <= 0"
	else:
		for child in child_nodes:
			if can_collapse:
				# If at least one child has children - we can't collapse children
				if child.child_nodes.size() > 0:
					can_collapse = false
					reason = "child.child_nodes.size() > 0"
					break
				else:
					total_member_count += child.get_member_count()
	
	if !can_collapse:
		print_address("", "can't collapse children: %s" % [reason])
	
	# We also need to have members below limit to trigger collapsing
	if can_collapse && total_member_count <= max_members:
		_collapse_children()


# Try to collapse self is possible
func try_collapse_self(instigator_child:int):
	print_address("", "try collapse self")
	var child_with_descendants := -1
	var can_collapse := true
	var reason:String
	
	# If no children - no collapsing
	if child_nodes.size() <= 0:
		can_collapse = false
		reason = "child_nodes.size() <= 0"
	else:
		for child in child_nodes:
			if can_collapse:
				# If child has members or children - it might become the new root
				if child.get_member_count() > 0 || !child.is_leaf:
					# But if there is more than one child with members or other children - we can't collapse self
					if child_with_descendants >= 0:
						can_collapse = false
						reason = "child_with_descendants >= 0"
						break
					else:
						child_with_descendants = child.octant
	
	if !can_collapse:
		print_address("", "can't collapse self: %s" % [reason])
	
	if can_collapse:
		# If condition fulfilled
		# Or an edgecase when child_nodes have no members or children at all (i.e. all members were removed in one pass)
		if child_with_descendants >= 0:
			collapse_self_possible.emit(child_with_descendants)
		else:
			collapse_self_possible.emit(instigator_child)


# Collapse children into one (their parent)
# Is meant to optimise members that can easily fit into a higher-level node
# (And thus save processing power on iterating over child nodes)
func _collapse_children():
	var total_placeforms := []
	for child in child_nodes:
		if child.is_leaf:
			total_placeforms.append_array(child.get_placeforms())
		child.free_octree_relationship_refs()
	child_nodes.clear()
	
	set_is_leaf(true)
	add_members(total_placeforms)

	if parent:
		parent.try_collapse_children(0)
	
	print_address("", "collapsed children")


# Collapse self by making one of the children a new root
# This action actually happens in an OctreeManager, since OctreeNodes cannot makes themselves root nodes
func collapse_self(new_root_octant:int):
	child_nodes.remove_at(new_root_octant)
	print_address("", "collapsed self")
	free_octree_relationship_refs()




#-------------------------------------------------------------------------------
# Utility
#-------------------------------------------------------------------------------


# Get total members in this node (from temporary placeform array)
func get_member_count() -> int:
	return member_placeforms.size()


# Call a function for each placeform of this node
func iter_placeforms(obj: Object, method: String):
	for placeform in member_placeforms:
		obj.call(method, placeform)


# Get a list of placeforms
func get_placeforms() -> Array:
	return member_placeforms


# Get an individual placeform
func get_placeform(member_idx: int) -> Array:
	return member_placeforms[member_idx]


# Recursively get all members contained by this node and it's children
func get_nested_placeforms(target_array: Array = []):
	if is_leaf:
		target_array.append_array(member_placeforms)
	else:
		for child in child_nodes:
			child.get_nested_placeforms(target_array)


# Recursively get member count in the whole octree
func get_nested_member_count() -> int:
	var member_count := 0
	
	if is_leaf:
		member_count += get_member_count()
	else:
		for child in child_nodes:
			member_count += child.get_nested_member_count()
	
	return member_count


# Recursively get a child by it's address (relative to the node of inception)
func find_child_by_address(address:PackedByteArray) -> Resource:
	return _find_child_by_address_impl(address.duplicate())


# IMPLEMENTATION Recursively get a child by it's address (relative to the node of inception)
func _find_child_by_address_impl(address:PackedByteArray) -> Resource:
	if address.is_empty(): return self
	if child_nodes.is_empty(): return null
	
	var child = child_nodes[address[0]]
	address.remove_at(0)
	return child._find_child_by_address_impl(address)


# Recursively get a full address of this node
func get_address(address:PackedByteArray = PackedByteArray()) -> PackedByteArray:
	if parent:
		address.insert(0, octant)
		return parent.get_address(address)
	return address


# Recursively get a full address of this node
func get_address_string() -> String:
	var string = str(get_address())
	string = string.replace("[", "")
	string = string.replace("]", "")
	string = string.replace(", ", "-")
	return string




#-------------------------------------------------------------------------------
# Point processing
#-------------------------------------------------------------------------------


# A switch to easily get a center offset for a given octant
func _get_octant_center_offset(octant:int):
	match octant:
		0: return Vector3(-extent, -extent, -extent)
		1: return Vector3(-extent, -extent, extent)
		2: return Vector3(-extent, extent, -extent)
		3: return Vector3(-extent, extent, extent)
		4: return Vector3(extent, -extent, -extent)
		5: return Vector3(extent, -extent, extent)
		6: return Vector3(extent, extent, -extent)
		7: return Vector3(extent, extent, extent)


# An optimized way to fit a point into one of the 8 inner cubes
# Assumes the point is inside node bounds already
func _map_point_to_octant(point:Vector3) -> int:
	var octant := 0
	if point.x > center_pos.x:
		octant += 4
	if point.y > center_pos.y:
		octant += 2
	if point.z > center_pos.z:
		octant += 1
	return octant


# An optimized way to fit a point into one of the 8 inner cubes, but diagonally opposite
# Is used to place this node within a new parent when growing to outside members
# Assumes the point is inside node bounds already
func _map_point_to_opposite_octant(point:Vector3) -> int:
	var octant := 0
	if point.x <= center_pos.x:
		octant += 4
	if point.y <= center_pos.y:
		octant += 2
	if point.z <= center_pos.z:
		octant += 1
	return octant




#-------------------------------------------------------------------------------
# Debug
#-------------------------------------------------------------------------------


# Request a debug redraw by passing it all the way to the root and then emitting a signal
func request_debug_redraw():
	if parent:
		parent.request_debug_redraw()
	else:
		req_debug_redraw.emit()


# Get a color depending on address length
func debug_get_color():
	var address = get_address()
	match address.size() % 3:
		0:
			return Color.RED
		1:
			return Color.YELLOW
		2:
			return Color.BLUE


# Recursively dump an entire octree
func debug_dump_tree(results:Dictionary = {"string": "", "total_members": 0}):
	var address = get_address()
	var string := ""
	for i in range(0, address.size()):
		string += "	"
	string += str(address)
	string += " LOD: %d" % [active_LOD_index]
	if is_leaf:
		string += " is leaf"
	if get_member_count() > 0:
		string += " members: %d" % [get_member_count()]
	
	results.string += string + "\n"
	
	if is_leaf:
		results.total_members += get_member_count()
	else:
		for child in child_nodes:
			child.debug_dump_tree(results)
	
	if !parent:
		results.string += "total members: %d" % [results.total_members]
		return results.string


# Print an address of this node with two optional messages (prefix and suffix)
func print_address(prefix:String = "", suffix:String = ""):
	if !FunLib.get_setting_safe("dreadpons_spatial_gardener/debug/octree_log_lifecycle", false): return
	var string = ""
	
	if prefix.length() > 0:
		string = prefix + string + " "
	string += str(get_address())
	if suffix.length() > 0:
		string = string + " " + suffix
	
	logger.info(string)
