tool
extends Resource


#-------------------------------------------------------------------------------
# Used to store placements and reference an MMI that represents them
# Meant to speed up iteration and split LOD management into faster, smaller and more manageable chunks
#-------------------------------------------------------------------------------

# Parent OctreeNodes do not have members of their own and delegate them to their children
# That is (in part) because no one member can exist in more than one OctreeNode
# Since member represents a position and has no volume


const FunLib = preload("../../utility/fun_lib.gd")
const Logger = preload("../../utility/logger.gd")
const Placeform = preload("../placeform.gd")
const Greenhouse_LODVariant = preload("../../greenhouse/greenhouse_LOD_variant.gd")

# An array for looking up placements conviniently
# Since a member placement is practically it's ID
var member_placeforms: Array = []
# And these are for storage on disk
export(PoolRealArray) var member_origin_offsets: PoolRealArray = PoolRealArray()
export(PoolVector3Array) var member_surface_normals: PoolVector3Array = PoolVector3Array()
export(PoolByteArray) var member_octants: PoolByteArray = PoolByteArray()

export(Array, Resource) var child_nodes:Array
export var max_members:int
export var min_leaf_extent:float

export var octant:int
export var is_leaf:bool

export var center_pos:Vector3
export var extent:float
export var bounds:AABB
export var max_bounds_to_center_dist:float
export var min_bounds_to_center_dist:float

var parent:Resource
var MMI_container:Spatial = null
var MMI:MultiMeshInstance = null
export var active_LOD_index:int = -1
export var MMI_name:String = ""

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
	__octant:int = -1, __min_leaf_extent:float = 0.0, __MMI_container:Spatial = null, __LOD_variants:Array = []):
	
	resource_local_to_scene = true
	set_meta("class", "MMIOctreeNode")
	resource_name = "MMIOctreeNode"
	
	logger = Logger.get_for(self)
	
	max_members = __max_members
	child_nodes = []
	reset_member_arrays()
	
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
		MMI_container = __MMI_container
		extent = __extent
		center_pos = __center_pos
		min_leaf_extent = __min_leaf_extent
		shared_LOD_variants = __LOD_variants
	
	set_is_leaf(true)
	max_bounds_to_center_dist = sqrt(pow(extent, 2) * 3)
	min_bounds_to_center_dist = extent
	bounds = AABB(center_pos - Vector3(extent, extent, extent), Vector3(extent, extent, extent) * 2.0)
	
	print_address("", "initialized")


# Duplictes the octree structure
func duplicate_tree():
	var copy = self.duplicate()
	# members should be new anyways after restore_placeforms()
	var child_nodes_copy = copy.child_nodes.duplicate()
	copy.child_nodes = []
	for child_node in child_nodes_copy:
		copy.child_nodes.append(child_node.duplicate_tree())
	return copy


# Inherit inheritable properties of a parent
func safe_inherit(__parent):
	parent = __parent
	extent = parent.extent * 0.5
	min_leaf_extent = parent.min_leaf_extent
	MMI_container = parent.MMI_container
	shared_LOD_variants = parent.shared_LOD_variants


# Reset properties, that represent parent inheritance (but otherwise serve no purpose)
func safe_init_root():
	parent = null
	octant = -1


# Cleanup this this node before deletion
# TODO find out if I can clear the member array here as well
func prepare_for_removal():
	print_address("", "prepare for removal")
	
	for child in child_nodes:
		child.prepare_for_removal()
	child_nodes = []
	
	set_is_leaf(false)


# Restore any states that might be broken after loading this node
func restore_after_load(__MMI_container:Spatial, LOD_variants:Array):
	MMI_container = __MMI_container
	shared_LOD_variants = LOD_variants
	
	validate_MMI()
	restore_placeforms()
	validate_member_spatials()
	
	for child in child_nodes:
		child.parent = self
		child.restore_after_load(MMI_container, LOD_variants)
	
	print_address("", "restored after load")


# Mark node as having or not having any members
# If yes, also create an MMI
func set_is_leaf(val):
	is_leaf = val
	if is_leaf && !is_instance_valid(MMI) && is_instance_valid(MMI_container):
		MMI = MultiMeshInstance.new()
		MMI_container.add_child(MMI, true)
		MMI.owner = MMI_container.owner
		MMI_name = MMI.name
		MMI.multimesh = MultiMesh.new()
		MMI.multimesh.resource_local_to_scene = true
		MMI.multimesh.transform_format = 1
	elif !is_leaf:
		if is_instance_valid(MMI) && is_instance_valid(MMI_container):
			MMI_container.remove_child(MMI)
			MMI.owner = null
		if MMI:
			MMI = null
		MMI_name = ""
	# NB this was previously under 'elif' check. Look out for unexpected behavior
	active_LOD_index = -1


func destroy():
	for child in child_nodes:
		child.destroy()
	child_nodes = []
	reset_member_arrays()




#-------------------------------------------------------------------------------
# LOD management
#-------------------------------------------------------------------------------


# Make sure LOD corresponds to the active_LOD_index
func set_LODs_to_active_index():
	if is_leaf:
		# We have LOD variants to choose from and an active_LOD_index is set
		if shared_LOD_variants.size() > active_LOD_index && active_LOD_index >= 0:
			var new_mesh = shared_LOD_variants[active_LOD_index].mesh
			# Our assigned mesh is different from the intended one
			if MMI.multimesh.mesh != new_mesh:
				# Assign the LOD variant mesh
				MMI.multimesh.mesh = new_mesh
				clear_and_spawn_all_member_spatials(active_LOD_index)
			# Update cast_shadow as well
			MMI.cast_shadow = shared_LOD_variants[active_LOD_index].cast_shadow
		else:
			# Reset LODS and spawned spatials
			clear_LOD_member_state()
	else:
		for child in child_nodes:
			child.set_LODs_to_active_index()


# Update LOD depending on node's distance to camera
func update_LODs(camera_pos:Vector3, LOD_max_distance:float, LOD_kill_distance:float):
	# If we don't have any LOD variants, abort the entire update process
	# We assume mesh and spatials are reset on shared_LOD_variants change using set_LODs_to_active_index() call from an arborist
	if shared_LOD_variants.empty(): return
	
	var dist_to_node_center := (center_pos - camera_pos).length()
	
	var max_LOD_dist := LOD_max_distance + min_bounds_to_center_dist #max_bounds_to_center_dist
	var max_kill_dist := LOD_kill_distance + min_bounds_to_center_dist #max_bounds_to_center_dist
	var dist_to_node_center_bounds_estimate := clamp(dist_to_node_center - max_bounds_to_center_dist, 0.0, INF)
	
	var skip_assignment := false
	var skip_children := false
	var max_LOD_index = shared_LOD_variants.size() - 1
	
	# If outside the kill threshold
	if LOD_kill_distance >= 0.0 && dist_to_node_center_bounds_estimate >= max_kill_dist:
		# If haven't yet reset MMIs and spawned spatials, reset them
		if active_LOD_index >= 0:
			active_LOD_index = -1
			if is_leaf:
				clear_LOD_member_state()
		# If up-to-date, skip assignment
		else:
			skip_children = true
		skip_assignment = true
	# If already at max LOD and outside of the max LOD threshold
	elif active_LOD_index == max_LOD_index && dist_to_node_center_bounds_estimate >= max_LOD_dist:
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
	
	# Skip if already assigned this LOD_index
	if active_LOD_index == LOD_index: return
	
	var last_LOD_index = active_LOD_index
	active_LOD_index = LOD_index
	
	# We need to set active_LOD_index on both leaves/non-leaves
	# But non-leaves do not have an MMI and can't spawn spatials
	if is_leaf:
		#print(MMI.multimesh)
		MMI.multimesh.mesh = shared_LOD_variants[LOD_index].mesh
		MMI.cast_shadow = shared_LOD_variants[LOD_index].cast_shadow
		clear_and_spawn_all_member_spatials(last_LOD_index)


# Reset MMIs and spawned spatials
func clear_LOD_member_state():
	MMI.multimesh.mesh = null
	clear_all_member_spatials()




#-------------------------------------------------------------------------------
# Member management
#-------------------------------------------------------------------------------


# Reset all arrays storing the member data
func reset_member_arrays():
	member_placeforms = []
	member_origin_offsets = PoolRealArray()
	member_surface_normals = PoolVector3Array()
	member_octants = PoolByteArray()


# Add new member data
func append_to_member_arrays(placeform: Array):
	member_placeforms.append(placeform)
	member_origin_offsets.append(Placeform.get_origin_offset(placeform))
	member_surface_normals.append(placeform[1])
	member_octants.append(placeform[3])


# Remove member data by placeform
func erase_from_member_arrays(placeform: Array):
	var member_idx = member_placeforms.find(placeform)
	remove_at_from_member_arrays(member_idx)


# Remove member data by index
func remove_at_from_member_arrays(member_idx: int):
	member_placeforms.remove(member_idx)
	member_origin_offsets.remove(member_idx)
	member_surface_normals.remove(member_idx)
	member_octants.remove(member_idx)


# Set member data by index
func set_member_arrays_at_index(idx:int, placeform: Array):
	member_placeforms[idx] = placeform
	member_origin_offsets.set(idx, Placeform.get_origin_offset(placeform))
	member_surface_normals.set(idx, placeform[1])
	member_octants.set(idx, placeform[3])


# Restore temporary placeforms after loading .tscn file
func restore_placeforms():
	if !is_leaf: return
	member_placeforms = []
	var MMI_inst_transform: Transform
	for idx in range(0, MMI.multimesh.instance_count):
		MMI_inst_transform = MMI.multimesh.get_instance_transform(idx)
		member_placeforms.append(Placeform.set_placement_from_origin_offset(
			Placeform.mk(
				Vector3(),
				member_surface_normals[idx],
				MMI_inst_transform,
				member_octants[idx]
			),
			member_origin_offsets[idx]
		))


# Add members to self, propagate them to children to request a growth from the OctreeManager
# This function is destructive to the passed array. Duplicate it if the original needs to stay intact
func add_members(new_placeforms:Array):
	# If we found any members outside this node - gather them up
	# And request a growth from OctreeManager to accommodate these members
	# Rejected members are put at the front since OctreeManager uses [0] to determine growth direction
	
	var rejected = reject_outside_placeforms(new_placeforms)
	if rejected.size() > 0:
		emit_signal("placeforms_rejected", rejected + new_placeforms)
		# Further execution can lead to members being added to a collapsed node
		# (OctreeManager tries to collapse children when growing to members)
		# So we abort
		return
	
	if new_placeforms.empty(): return
	# Mark this node as 'dirty' to make sure it gets update in the next update_LODs()
	active_LOD_index = 0
	
	assign_octants_to_placeforms(new_placeforms)
	
	var members_changed := false
	if extent * 0.5 >= min_leaf_extent:
		if child_nodes.empty() && member_count() + new_placeforms.size() > max_members:
			_make_children()
			iter_placeforms(self, '_add_member_to_child')
			reset_member_arrays()
	
	if !child_nodes.empty():
		for placeform in new_placeforms:
			_add_member_to_child(placeform)
	else:
		for placeform in new_placeforms:
			append_to_member_arrays(placeform)
			spawn_spatial_for_member_idx(member_count() - 1)
			print_address("", "adding placeform " + Placeform.to_str(placeform))
			members_changed = true
	
	if members_changed && parent:
		parent._child_added_members(octant)


# Remove members from self, or children
# This function is destructive to the passed array. Duplicate it if the original needs to stay intact
func remove_members(old_placeforms:Array):
	if old_placeforms.empty(): return
	# Mark this node as 'dirty' to make sure it gets update in the next update_LODs()
	active_LOD_index = 0
	
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
				remove_spatial_for_member_idx(found_placement_idx)
				remove_at_from_member_arrays(found_placement_idx)
				print_address("", "erased placeform " + Placeform.to_str(placeform))
				members_changed = true
	
	if members_changed && parent:
		parent._child_removed_members(octant)


# Update members' Transforms at given address
func set_members(changes:Array):
	# Mark this node as 'dirty' to make sure it gets update in the next update_LODs()
	active_LOD_index = 0
	
	for change in changes:
		var octree_node = find_child_by_address(change.address)
		octree_node.set_member_arrays_at_index(change.index, change.placeform)
		octree_node.MMI_refresh_member(change.index, change.placeform[2])
		octree_node.set_spatial_for_member_idx(change.index)


# Rejects members outside the bounds
func reject_outside_placeforms(new_placeforms:Array):
	if parent || new_placeforms.empty(): return []
	
	var rejected := []
	for i in range(new_placeforms.size() - 1, -1, -1):
		var placeform = new_placeforms[i]
		if !bounds.has_point(placeform[0]):
			rejected.append(placeform)
			new_placeforms.remove(i)
	
	return rejected


# Map members to octants within this node (i.e. place inside a 2x2x2 cube)
# It's mostly used to quick access the child node holding this member
func assign_octants_to_placeforms(new_placeforms: Array):
	for placeform in new_placeforms:
		placeform[3] = _map_point_to_octant(placeform[0])


func _add_member_to_child(new_placeform: Array):
	child_nodes[new_placeform[3]].add_members([new_placeform])


func _remove_member_from_child(old_placeform: Array):
	child_nodes[old_placeform[3]].remove_members([old_placeform])




#-------------------------------------------------------------------------------
# MMI and spawned spatial management
#-------------------------------------------------------------------------------


# Make sure our MMI exists and is, in fact, a MultiMeshInstance
# If not - delete it, and recreate inside set_is_leaf()
func validate_MMI():
	MMI = MMI_container.get_node_or_null(MMI_name)
	if MMI && !(MMI is MultiMeshInstance):
		MMI_container.remove_child(MMI)
		MMI.owner = null
		MMI = null
		MMI_name = ""
	set_is_leaf(is_leaf)


# Make sure all neccessary spawned spatials exist
func validate_member_spatials():
	if !is_leaf: return
	if shared_LOD_variants.size() <= active_LOD_index || active_LOD_index == -1: return
	var LODVariant:Greenhouse_LODVariant = shared_LOD_variants[active_LOD_index]
	if !LODVariant || !LODVariant.spawned_spatial: return
	
	# Create an example spatial for class checks
	var spawned_spatial = LODVariant.spawned_spatial.instance()
	
	# Remove spatials of wrong class
	# Update those that are of correct class
	for index in range(MMI.get_child_count() - 1, -1, -1):
		var child_spatial = MMI.get_child(index)
		if !FunLib.are_same_class(child_spatial, spawned_spatial):
			remove_spatial_for_member_idx(index)
		elif index < member_count():
			child_spatial.transform = get_member_transform(index)
	
	# Spawn all the missing spatials
	for index in range(MMI.get_child_count(), member_count()):
		spawn_spatial_for_member_idx(index)


# Spawn a spatial for member
func spawn_spatial_for_member_idx(member_idx:int, mmi_idx:int = -1):
	if shared_LOD_variants.size() <= active_LOD_index || active_LOD_index == -1: return
	var LODVariant:Greenhouse_LODVariant = shared_LOD_variants[active_LOD_index]
	if !LODVariant || !LODVariant.spawned_spatial: return
	
	var spawned_spatial = LODVariant.spawned_spatial.instance()
	spawned_spatial.transform = get_member_transform(member_idx)
	MMI.add_child(spawned_spatial)
	spawned_spatial.owner = MMI.owner
	if mmi_idx >= 0:
		MMI.move_child(spawned_spatial, mmi_idx)


# Remove a spatial for member
func remove_spatial_for_member_idx(member_idx:int):
	if MMI.get_child_count() > member_idx:
		MMI.remove_child(MMI.get_child(member_idx))


# Set spatial's Transform for member
func set_spatial_for_member_idx(member_idx: int):
	if member_idx >= MMI.get_child_count(): return
	MMI.get_child(member_idx).transform = get_member_transform(member_idx)


func get_member_transform(member_idx: int):
	return member_placeforms[member_idx][2]


func reset_member_spatials():
	clear_and_spawn_all_member_spatials()
	for child in child_nodes:
		child.reset_member_spatials()


# Clear all spatials and spawn them anew
# This is used to update spatials in case their LOD variant changes
func clear_and_spawn_all_member_spatials(last_LOD_index:int = -1):
	# Here we compare spawned_spatials before and after changing an LOD index
	# When they're the same - no need to update the spawned_spatials
	# But first, make sure our shared_LOD_variants actually contain that index
	if shared_LOD_variants.size() > last_LOD_index && last_LOD_index >= 0:
		# Then compare spawned_spatials themselves
		if shared_LOD_variants[last_LOD_index].spawned_spatial == shared_LOD_variants[active_LOD_index].spawned_spatial:
			return
	
	clear_all_member_spatials()
	spawn_all_member_spatials()


func clear_all_member_spatials():
	FunLib.clear_children(MMI)


func spawn_all_member_spatials():
	for member_idx in member_count():
		spawn_spatial_for_member_idx(member_idx)


# Recursively MMI_refresh_instance_placements()
func MMI_refresh_instance_placements_recursive():
	if is_leaf:
		MMI_refresh_instance_placements()
	else:
		for child in child_nodes:
			child.MMI_refresh_instance_placements_recursive()


# Reset MMI instances and set them anew in response to adding or removing new members via painting
# This can be faster if we won't change instance_count each time (use max_members instead)
# But Idk if allocated and hidden instances (with reduced visible_instance_count) still tank GPU perfomance or not
# If they do, we're better off keeping things as is to have better in-game performance
func MMI_refresh_instance_placements():
	MMI.multimesh.instance_count = member_count()
	for member_idx in range(0, member_count()):
		MMI.multimesh.set_instance_transform(member_idx, member_placeforms[member_idx][2])


# Refresh member Transform when reapplying a new Transform
# This avoids completely refreshing all instances like in MMI_refresh_instance_placements()
func MMI_refresh_member(member_idx: int, transform: Transform):
	assert(MMI.multimesh.instance_count > member_idx, "Trying to refresh multimesh instance [%d] that isn't allocated!" % [member_idx])

	MMI.multimesh.set_instance_transform(member_idx, transform)




#-------------------------------------------------------------------------------
# Child nodes management
#-------------------------------------------------------------------------------


# Create 8 child nodes that represent a deeper layer of this tree
func _make_children():
	var self_class = get_script()
	for octant in range(0, 8):
		var child = self_class.new(self, max_members, 0.0, Vector3.ZERO, octant)
		child_nodes.append(child)
	set_is_leaf(false)


# Adopt another OctreeNode as a child in a given octant
func adopt_child(child, octant:int):
	if child_nodes.empty():
		_make_children()
	
	child_nodes[octant].prepare_for_removal()
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
					total_member_count += child.member_count()
	
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
				if child.member_count() > 0 || !child.is_leaf:
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
			emit_signal("collapse_self_possible", child_with_descendants)
		else:
			emit_signal("collapse_self_possible", instigator_child)


# Collapse children into one (their parent)
# Is meant to optimise members that can easily fit into a higher-level node
# (And thus save processing power on iterating over child nodes)
func _collapse_children():
	var total_placeforms := []
	for child in child_nodes:
		if child.is_leaf:
			total_placeforms.append_array(child.get_placeforms())
		child.prepare_for_removal()
	child_nodes = []
	set_is_leaf(true)
	
	add_members(total_placeforms)
	
	if parent:
		parent.try_collapse_children(0)
	
	print_address("", "collapsed children")


# Collapse self by making one of the children a new root
# This action actually happens in an OctreeManager, since OctreeNodes cannot makes themselves root nodes
func collapse_self(new_root_octant:int):
	child_nodes.remove(new_root_octant)
	print_address("", "collapsed self")
	prepare_for_removal()




#-------------------------------------------------------------------------------
# Utility
#-------------------------------------------------------------------------------


# Get total members in this node (from temporary placeform array)
func member_count() -> int:
	return member_placeforms.size()


# Call a function for each placeform of this node
func iter_placeforms(obj: Object, method: String):
	for placeform in member_placeforms:
		obj.call(method, placeform)


# Get a list of placeforms
func get_placeforms() -> Array:
	return member_placeforms


# Get an individual placeform
func get_placeform(member_idx: int) -> Reference:
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
		member_count += member_count()
	else:
		for child in child_nodes:
			member_count += child.get_nested_member_count()
	
	return member_count


# Recursively get a child by it's address (relative to the node of inception)
func find_child_by_address(address:PoolByteArray) -> Resource:
	if address.empty(): return self
	if child_nodes.empty(): return null
	
	var child = child_nodes[address[0]]
	address.remove(0)
	return child.find_child_by_address(address)


# Recursively get a full address of this node
func get_address(address:PoolByteArray = PoolByteArray()) -> PoolByteArray:
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
		emit_signal("req_debug_redraw")


# Get a color depending on address length
func debug_get_color():
	var address = get_address()
	match address.size() % 3:
		0:
			return Color.red
		1:
			return Color.yellow
		2:
			return Color.blue


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
	if member_count() > 0:
		string += " members: %d" % [member_count()]
	
	results.string += string + "\n"
	
	if is_leaf:
		results.total_members += member_count()
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
