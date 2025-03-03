@tool
extends RefCounted # TODO: explore changing this to Object

#-------------------------------------------------------------------------------
# This is a sort of "blackbox" that handles ALL logic for actually placing instances
# Changing their LODs and keeping track of used resources (RenderServer RIDs, NOdes, etc.)
#
# Our motivation with this is to isolate highly situational logic of allocating
# Resources and drawing instances from the logic of managing an octree
# It means we can add instances and move them around the octree
# Without having to depend in any way on MultiMeshes and Nodes
# (This makes it trivial to place Node3D instances without a Mesh being assigned)
# (Or having some other weird AF configuration of LODVariants)
#
# The architecture of this object relies on "events" happening ( func on_*() )and OctreeLeaf
# Checking all relevant conditions and deciding which operations can be performed
# (If a given change allows us to spawn Mesh instances or demands we remove all Spawned Spatials, for example)
#-------------------------------------------------------------------------------


const Greenhouse_LODVariant = preload("../../greenhouse/greenhouse_LOD_variant.gd")
const FunLib = preload("../../utility/fun_lib.gd")
const Globals = preload("../../utility/globals.gd")

const multimesh_buffer_size: int = 12

var _octree_node = null
var _is_leaf: bool = false
var _active_LOD_index: int = -1

# TODO: to properly place spatial instances we need to manually account for _spawned_spatial_container's transform
#		this is counterintuitive, we should switch to local transforms across the whole plugin around 2.0.0
var _spawned_spatial_container: Node3D = null
var _RID_instance: RID = RID()
var _RID_multimesh: RID = RID()

var _mesh: Mesh = null
var _spawned_spatial: PackedScene = null
var _cast_shadow: RenderingServer.ShadowCastingSetting = RenderingServer.SHADOW_CASTING_SETTING_OFF

var _current_state: StateType = 0

enum StateType {
	INSTANCES_PERMITTED				= 0b0000_0000_0000_0000_0000_0000_0000_0001,
	MESH_VALID 						= 0b0000_0000_0000_0000_0000_0000_0000_0010,
	SPATIAL_VALID 					= 0b0000_0000_0000_0000_0000_0000_0000_0100,
	MESH_DEPS_INITIALIZED 			= 0b0000_0000_0000_0000_0000_0000_0000_1000,
	SPATIAL_DEPS_INITIALIZED 		= 0b0000_0000_0000_0000_0000_0000_0001_0000,
}

enum LODVariantParam {
	MESH, SPATIAL, SHADOW
}




#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


func _init(
	p_octree_node = null, p_is_leaf: bool = false, p_active_LOD_index: int = -1,
	p_spawned_spatial_container: Node3D = null, p_RID_instance: RID = RID(), p_RID_multimesh: RID = RID(),
	p_mesh: Mesh = null, p_spawned_spatial: PackedScene = null, p_cast_shadow: RenderingServer.ShadowCastingSetting = RenderingServer.SHADOW_CASTING_SETTING_OFF,
	p_current_state: StateType = 0
	):
		_octree_node = p_octree_node
		_is_leaf = p_is_leaf
		_active_LOD_index = p_active_LOD_index
		_spawned_spatial_container = p_spawned_spatial_container
		_RID_instance = _RID_instance
		_RID_multimesh = p_RID_multimesh
		_mesh = p_mesh
		_spawned_spatial = p_spawned_spatial
		_cast_shadow = p_cast_shadow
		_current_state = p_current_state


func clone(p_octree_node) -> RefCounted:
	var clone = get_script().new(
		p_octree_node, _is_leaf, _active_LOD_index,
		null, RID(), RID(),
		_mesh, _spawned_spatial, _cast_shadow,
		0)
	return clone


# Free anything that might incur a circular reference or a memory leak
# Anything that is @export'ed is NOT touched here
# We count on Godot's own systems to handle that in whatever way works best
func free_circular_refs():
	if _current_state & StateType.MESH_DEPS_INITIALIZED: 
		_deinit_mesh_dependencies()
	if _current_state & StateType.SPATIAL_DEPS_INITIALIZED: 
		_deinit_spawned_spatial_dependencies()

	_octree_node = null


# "Restore" circular references freed in free_circular_refs() 
# (e.g. when exiting and then entering the tree again)
func restore_circular_refs(p_octree_node: Resource):
	set_octree_node(p_octree_node)




#-------------------------------------------------------------------------------
# Octree event handling
#-------------------------------------------------------------------------------


func get_current_state() -> StateType:
	return _current_state


# Check conditions for a single state and turn it on/off
func _update_state(p_single_state_type: StateType):
	match p_single_state_type:
		StateType.INSTANCES_PERMITTED:
			if is_instance_valid(_octree_node) && _octree_node.is_leaf && is_instance_valid(_octree_node.gardener_root) && _octree_node.get_member_count():
				_current_state |= StateType.INSTANCES_PERMITTED
			else:
				_current_state &= ~StateType.INSTANCES_PERMITTED
		StateType.MESH_VALID:
			if is_instance_valid(_mesh) && is_instance_valid(_octree_node) && is_instance_valid(_octree_node.gardener_root) && _octree_node.gardener_root.is_visible_in_tree():
				_current_state |= StateType.MESH_VALID
			else:
				_current_state &= ~StateType.MESH_VALID
		StateType.SPATIAL_VALID:
			if is_instance_valid(_spawned_spatial):
				_current_state |= StateType.SPATIAL_VALID
			else:
				_current_state &= ~StateType.SPATIAL_VALID
		StateType.MESH_DEPS_INITIALIZED:
			if _RID_instance.is_valid() && _RID_multimesh.is_valid():
				_current_state |= StateType.MESH_DEPS_INITIALIZED
			else:
				_current_state &= ~StateType.MESH_DEPS_INITIALIZED
		StateType.SPATIAL_DEPS_INITIALIZED:
			if is_instance_valid(_spawned_spatial_container) && _spawned_spatial_container.is_inside_tree():
				_current_state |= StateType.SPATIAL_DEPS_INITIALIZED
			else:
				_current_state &= ~StateType.SPATIAL_DEPS_INITIALIZED


# Getting LODVariant values in a safe way (avoiding invalid access, null pointers, etc.)
func _get_variant_param(p_param: LODVariantParam, p_default_val = null):
	# NOTE: _octree_node assumed valid at this point
	if _octree_node.active_LOD_index < 0 || _octree_node.shared_LOD_variants.size() <= _octree_node.active_LOD_index:
		return p_default_val
	var lod_variant = _octree_node.shared_LOD_variants[_octree_node.active_LOD_index]
	if !is_instance_valid(lod_variant):
		return p_default_val
	match p_param:
		LODVariantParam.MESH:
			return lod_variant.mesh
		LODVariantParam.SPATIAL:
			return lod_variant.spawned_spatial
		LODVariantParam.SHADOW:
			return lod_variant.cast_shadow


func set_octree_node(p_octree_node):
	if _octree_node == p_octree_node: return
	_octree_node = p_octree_node
	
	if _octree_node.gardener_root == null: return # We assume this means restore_after_load() will be called afterwards
	_init_with_octree_node()


func restore_after_load():
	_init_with_octree_node()


# This can be called by both set_octree_node() and restore_after_load()
# We need this to ensure we can avoid double-initialization when e.g. loading from disk
func _init_with_octree_node():
	# Inherit leaf, mesh, spawned spatial, shadow, create new spatial container if necessary
	if _octree_node == null:
		_is_leaf = false
		_active_LOD_index = -1
		_mesh = null
		_spawned_spatial = null
		_cast_shadow = RenderingServer.SHADOW_CASTING_SETTING_OFF
	else:
		_is_leaf = _octree_node.is_leaf
		_active_LOD_index = _octree_node.active_LOD_index
		_mesh = _get_variant_param(LODVariantParam.MESH)
		_spawned_spatial = _get_variant_param(LODVariantParam.SPATIAL)
		_cast_shadow = _get_variant_param(LODVariantParam.SHADOW, RenderingServer.SHADOW_CASTING_SETTING_OFF)
		if _current_state & StateType.SPATIAL_DEPS_INITIALIZED: # If spatial deps initialized
			if _octree_node.gardener_root != _spawned_spatial_container.get_parent(): # And new gardener root is different from current spatial container
				_deinit_spawned_spatial_dependencies() # Deitialize spatial deps (they will be reinitialized further down)
	_update_state(StateType.INSTANCES_PERMITTED)
	_update_state(StateType.MESH_VALID)
	_update_state(StateType.SPATIAL_VALID)

	if _current_state & StateType.INSTANCES_PERMITTED: # If instances can exist
		# Multimesh
		if _current_state & StateType.MESH_VALID: # If mesh valid
			if _current_state & StateType.MESH_DEPS_INITIALIZED == 0: # If mesh deps not initialized
				_init_mesh_dependencies() # Initialize mesh deps
			_update_mesh() # Set mesh 
			_update_shadow() # Set shadow
			_replace_all_mesh_instances() # Replace all mesh instances (assume might already have lefovers)
		elif _current_state & StateType.MESH_DEPS_INITIALIZED: # Elif mesh deps initialized
			_deinit_mesh_dependencies() # Deitialize mesh deps
		# Spatials
		if _current_state & StateType.SPATIAL_VALID: # If spatial valid
			if _current_state & StateType.SPATIAL_DEPS_INITIALIZED == 0: # If spatial deps not initialized
				_init_spawned_spatial_dependencies() # Initialize spatial deps
			_replace_all_spatial_instances() # Replace all spatial instances (assume might already have lefovers)
		elif _current_state & StateType.SPATIAL_DEPS_INITIALIZED: # Elif spatial deps initialized
			_deinit_spawned_spatial_dependencies() # Deitialize spatial deps
	# Cleanup
	else: # Else
		if _current_state & StateType.MESH_DEPS_INITIALIZED: # If mesh deps initialized
			_deinit_mesh_dependencies() # Deitialize mesh deps
		if _current_state & StateType.SPATIAL_DEPS_INITIALIZED: # If spatial deps initialized
			_deinit_spawned_spatial_dependencies() # Deitialize spatial deps


func on_is_leaf_changed(p_is_leaf: bool):
	if _is_leaf == p_is_leaf: return
	_is_leaf = p_is_leaf

	_update_state(StateType.INSTANCES_PERMITTED)

	if _current_state & StateType.INSTANCES_PERMITTED: # If instances can exist
		# Multimesh
		if _current_state & StateType.MESH_VALID: # If mesh valid
			if _current_state & StateType.MESH_DEPS_INITIALIZED == 0: # If mesh deps not initialized
				_init_mesh_dependencies() # Initialize mesh deps
			_update_mesh() # Set mesh 
			_update_shadow() # Set shadow
			_replace_all_mesh_instances() # Replace all mesh instances (assume might already have lefovers)
		elif _current_state & StateType.MESH_DEPS_INITIALIZED: # Elif mesh deps initialized
			_deinit_mesh_dependencies() # Deitialize mesh deps
		# Spatials
		if _current_state & StateType.SPATIAL_VALID: # If spatial valid
			if _current_state & StateType.SPATIAL_DEPS_INITIALIZED == 0: # If spatial deps not initialized
				_init_spawned_spatial_dependencies() # Initialize spatial deps
			_replace_all_spatial_instances() # Replace all spatial instances (assume might already have lefovers)
		elif _current_state & StateType.SPATIAL_DEPS_INITIALIZED: # Elif spatial deps initialized
			_deinit_spawned_spatial_dependencies() # Deitialize spatial deps
	# Cleanup
	else: # Else
		if _current_state & StateType.MESH_DEPS_INITIALIZED: # If mesh deps initialized
			_deinit_mesh_dependencies() # Deitialize mesh deps
		if _current_state & StateType.SPATIAL_DEPS_INITIALIZED: # If spatial deps initialized
			_deinit_spawned_spatial_dependencies() # Deitialize spatial deps


func on_active_lod_index_changed():
	if _active_LOD_index == _octree_node.active_LOD_index: return
	_active_LOD_index = _octree_node.active_LOD_index

	_update_with_active_lod_variant()


func on_preceeding_lod_variant_changed():
	_update_with_active_lod_variant()


# This method may have multiple points of entry
# Basically called in response that may cause ANY change to the active LODVariant
# (LODVariant itself or its Mesh/Spatial/Shadow)
func _update_with_active_lod_variant():
	# Inherit mesh, spawned spatial, shadow
	var change_flags: int = 0
	var new_mesh = _get_variant_param(LODVariantParam.MESH)
	var new_shadow = _get_variant_param(LODVariantParam.SHADOW, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	var new_spatial = _get_variant_param(LODVariantParam.SPATIAL)

	if _mesh != new_mesh:
		_mesh = new_mesh
		change_flags |= 0b001
	if _cast_shadow != new_shadow:
		_cast_shadow = new_shadow
		change_flags |= 0b010
	if _spawned_spatial != new_spatial:
		_spawned_spatial = new_spatial
		change_flags |= 0b100
	_update_state(StateType.MESH_VALID)
	_update_state(StateType.SPATIAL_VALID)

	if _current_state & StateType.INSTANCES_PERMITTED == 0: # If instances can't exist
		return # Return (current function couldn't have altered this)
	
	# Multimesh
	if change_flags & 0b001: # If mesh changed
		if _current_state & StateType.MESH_VALID: # If mesh valid
			if _current_state & StateType.MESH_DEPS_INITIALIZED == 0: # If mesh deps not initialized
				_init_mesh_dependencies() # Initialize mesh deps
				_add_all_mesh_instances() # Add all mesh instances (assume we're currently empty)
				_update_shadow() # Set shadow
			_update_mesh() # Set mesh 
		elif _current_state & StateType.MESH_DEPS_INITIALIZED: # Elif mesh deps initialized
			_deinit_mesh_dependencies() # Deitialize mesh deps
	if change_flags & 0b010: # If shadow changed
		if _current_state & StateType.MESH_DEPS_INITIALIZED: # If mesh deps initialized
			_update_shadow() # Set shadow
	# Spatials
	if change_flags & 0b100: # If spatial changed
		if _current_state & StateType.SPATIAL_VALID: # If spatial valid
			if _current_state & StateType.SPATIAL_DEPS_INITIALIZED == 0: # If spatial deps not initialized
				_init_spawned_spatial_dependencies() # Initialize spatial deps
			_replace_all_spatial_instances() # Replace all spatial instances (full replacement is the only way to update them)
		elif _current_state & StateType.SPATIAL_DEPS_INITIALIZED: # Elif spatial deps initialized
			_deinit_spawned_spatial_dependencies() # Deitialize spatial deps


func on_active_lod_variant_mesh_changed():
	var new_mesh = _get_variant_param(LODVariantParam.MESH)
	if _mesh == new_mesh: return

	# Inherit mesh
	_mesh = new_mesh
	_update_state(StateType.MESH_VALID)

	if _current_state & StateType.INSTANCES_PERMITTED == 0: # If instances can't exist
		return # Return (current function couldn't have altered this)
	
	if _current_state & StateType.MESH_VALID: # If mesh valid
		if _current_state & StateType.MESH_DEPS_INITIALIZED == 0: # If mesh deps not initialized
			_init_mesh_dependencies() # Initialize mesh deps
			_add_all_mesh_instances() # Add all mesh instances (assume we're currently empty)
			_update_shadow() # Set shadow
		_update_mesh() # Set mesh 
	elif _current_state & StateType.MESH_DEPS_INITIALIZED: # Elif mesh deps initialized
		_deinit_mesh_dependencies() # Deitialize mesh deps


func on_active_lod_variant_shadow_changed():
	var new_shadow = _get_variant_param(LODVariantParam.SHADOW, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	if _cast_shadow == new_shadow: return

	# Inherit shadow
	_cast_shadow = new_shadow

	if _current_state & StateType.INSTANCES_PERMITTED == 0: # If instances can't exist
		return # Return (current function couldn't have altered this)
	
	if _current_state & StateType.MESH_DEPS_INITIALIZED: # If mesh deps initialized
		_update_shadow() # Set shadow 
	pass


func on_active_lod_variant_spatial_changed():
	var new_spatial = _get_variant_param(LODVariantParam.SPATIAL)
	if _spawned_spatial == new_spatial: return

	# Inherit spawned spatial
	_spawned_spatial = new_spatial
	_update_state(StateType.SPATIAL_VALID)

	if _current_state & StateType.INSTANCES_PERMITTED == 0: # If instances can't exist
		return # Return (current function couldn't have altered this)
	
	if _current_state & StateType.SPATIAL_VALID: # If spatial valid
		if _current_state & StateType.SPATIAL_DEPS_INITIALIZED == 0: # If spatial deps not initialized
			_init_spawned_spatial_dependencies() # Initialize spatial deps
		_replace_all_spatial_instances() # Replace all spatial instances (full replacement is the only way to update them)
	elif _current_state & StateType.SPATIAL_DEPS_INITIALIZED: # Elif spatial deps initialized
		_deinit_spawned_spatial_dependencies() # Deitialize spatial deps


func on_reset_placeforms():
	_update_state(StateType.INSTANCES_PERMITTED)
	if _current_state & StateType.MESH_DEPS_INITIALIZED: # If mesh deps initialized
		_deinit_mesh_dependencies() # Deitialize mesh deps
	if _current_state & StateType.SPATIAL_DEPS_INITIALIZED: # If spatial deps initialized
		_deinit_spawned_spatial_dependencies() # Deitialize spatial deps


func on_appended_placeforms(p_placeforms: Array):
	_update_state(StateType.INSTANCES_PERMITTED) # These could be the first instances we add, make sure flags update if so

	# Multimesh
	if _current_state & StateType.MESH_VALID: # If mesh valid
		if _current_state & StateType.MESH_DEPS_INITIALIZED == 0: # If mesh deps not initialized
			_init_mesh_dependencies() # Initialize mesh deps
			_update_mesh() # Set mesh 
			_update_shadow() # Set shadow
		_add_mesh_instances(p_placeforms) # Add mesh instances (assume other instances are already up to date)
	# Spatials
	if _current_state & StateType.SPATIAL_VALID: # If spatial valid
		if _current_state & StateType.SPATIAL_DEPS_INITIALIZED == 0: # If spatial deps not initialized
			_init_spawned_spatial_dependencies() # Initialize spatial deps
		_add_spatial_instances(p_placeforms) # Add spatial instances (assume other instances are already up to date)


func on_removed_placeform_at(p_idx: int):
	_update_state(StateType.INSTANCES_PERMITTED)
	if _current_state & StateType.INSTANCES_PERMITTED == 0: # If instances can't exist
		if _current_state & StateType.MESH_DEPS_INITIALIZED: # If mesh deps initialized
			_deinit_mesh_dependencies() # Deitialize mesh deps
		if _current_state & StateType.SPATIAL_DEPS_INITIALIZED: # If spatial deps initialized
			_deinit_spawned_spatial_dependencies() # Deitialize spatial deps
	else: # Else
		if _current_state & StateType.MESH_DEPS_INITIALIZED: # If mesh deps initialized
			_remove_mesh_instance(p_idx) # Remove mesh instance (assume other instances are already up to date)
		if _current_state & StateType.SPATIAL_DEPS_INITIALIZED: # If spatial deps initialized
			_remove_spatial_instance(p_idx) # Remove spatial instance (assume other instances are already up to date)


func on_set_placeform_at(p_idx: int, p_placeform: Array):
	if _current_state & StateType.MESH_DEPS_INITIALIZED: # If mesh deps initialized
		_set_mesh_instance(p_idx, p_placeform) # Set mesh instance (assume other instances are already up to date)
	if _current_state & StateType.SPATIAL_DEPS_INITIALIZED: # If spatial deps initialized
		_set_spatial_instance(p_idx, p_placeform) # Set spatial instance (assume other instances are already up to date)


func on_root_transform_changed(p_global_transform: Transform3D):
	if _current_state & StateType.MESH_DEPS_INITIALIZED: # If mesh deps initialized
		_set_mesh_root_transform(p_global_transform)


func on_root_visibility_changed(p_visible: bool):
	_update_state(StateType.MESH_VALID)
	if p_visible:
		if _current_state & StateType.INSTANCES_PERMITTED: # If instances can exist
			if _current_state & StateType.MESH_VALID: # If mesh valid
				if _current_state & StateType.MESH_DEPS_INITIALIZED == 0: # If mesh deps not initialized
					_init_mesh_dependencies() # Initialize mesh deps
					_update_shadow() # Set shadow
					_update_mesh() # Set mesh 
					_add_all_mesh_instances() # Add all mesh instances (assume we're currently empty)
	else:
		if _current_state & StateType.MESH_DEPS_INITIALIZED: # If mesh deps initialized
			_deinit_mesh_dependencies() # Deitialize mesh deps




#-------------------------------------------------------------------------------
# State management
#-------------------------------------------------------------------------------


func _init_mesh_dependencies():
	var rendering_scenario_RID = _octree_node.gardener_root.get_world_3d().scenario
	_RID_multimesh = RenderingServer.multimesh_create()
	_RID_instance = RenderingServer.instance_create2(_RID_multimesh, rendering_scenario_RID)
	RenderingServer.instance_set_transform(_RID_instance, _octree_node.gardener_root.global_transform)
	_update_state(StateType.MESH_DEPS_INITIALIZED)


func _init_spawned_spatial_dependencies():
	var force_readable_node_name = Globals.force_readable_node_names
	_spawned_spatial_container = Node3D.new()
	_spawned_spatial_container.set_meta("octree_address", _octree_node.get_address())
	_octree_node.gardener_root.add_child(_spawned_spatial_container, force_readable_node_name)
	_spawned_spatial_container.transform = Transform3D()
	_update_state(StateType.SPATIAL_DEPS_INITIALIZED)


func _deinit_mesh_dependencies():
	RenderingServer.free_rid(_RID_multimesh)
	RenderingServer.free_rid(_RID_instance)
	_RID_multimesh = RID()
	_RID_instance = RID()
	_update_state(StateType.MESH_DEPS_INITIALIZED)


func _deinit_spawned_spatial_dependencies():
	FunLib.free_children(_spawned_spatial_container)
	_spawned_spatial_container.get_parent().remove_child(_spawned_spatial_container)
	_spawned_spatial_container.queue_free()
	_spawned_spatial_container = null
	_update_state(StateType.SPATIAL_DEPS_INITIALIZED)


func _set_mesh_root_transform(p_global_transform: Transform3D):
	RenderingServer.instance_set_transform(_RID_instance, p_global_transform)


func _update_mesh():
	RenderingServer.multimesh_set_mesh(_RID_multimesh, _mesh.get_rid())


func _update_shadow():
	RenderingServer.instance_geometry_set_cast_shadows_setting(_RID_instance, _cast_shadow)


func _add_all_mesh_instances():
	var instance_count = _octree_node.get_member_count()
	RenderingServer.multimesh_allocate_data(_RID_multimesh, instance_count, RenderingServer.MULTIMESH_TRANSFORM_3D, false, false)
	for i in range(0, instance_count):
		RenderingServer.multimesh_instance_set_transform(_RID_multimesh, i, _octree_node.member_placeforms[i][2])


func _add_all_spatial_instances():
	var force_readable_node_name = Globals.force_readable_node_names
	var instance_count = _octree_node.get_member_count()
	var spatial = null
	for i in range(0, instance_count):
		spatial = _spawned_spatial.instantiate()
		_spawned_spatial_container.add_child(spatial, force_readable_node_name)
		spatial.global_transform = _spawned_spatial_container.global_transform * _octree_node.member_placeforms[i][2]


func _replace_all_mesh_instances():
	_add_all_mesh_instances() # Multimesh needs no additional cleanup for replacing existing instances


func _replace_all_spatial_instances():
	FunLib.free_children(_spawned_spatial_container)
	_add_all_spatial_instances()


func _add_mesh_instances(p_placeforms: Array):
	var instance_count = RenderingServer.multimesh_get_instance_count(_RID_multimesh)
	var buffer = RenderingServer.multimesh_get_buffer(_RID_multimesh)
	RenderingServer.multimesh_allocate_data(_RID_multimesh, instance_count + p_placeforms.size(), RenderingServer.MULTIMESH_TRANSFORM_3D, false, false)
	var trans: Transform3D
	for i in range(0, p_placeforms.size()):
		trans = p_placeforms[i][2]
		buffer.append_array([
			trans.basis.x.x, trans.basis.y.x, trans.basis.z.x, trans.origin.x,
			trans.basis.x.y, trans.basis.y.y, trans.basis.z.y, trans.origin.y,
			trans.basis.x.z, trans.basis.y.z, trans.basis.z.z, trans.origin.z
		])
	RenderingServer.multimesh_set_buffer(_RID_multimesh, buffer)


func _add_spatial_instances(p_placeforms: Array):
	var force_readable_node_name = Globals.force_readable_node_names
	var spatial = null
	for i in range(0, p_placeforms.size()):
		spatial = _spawned_spatial.instantiate()
		_spawned_spatial_container.add_child(spatial, force_readable_node_name)
		spatial.global_transform = _spawned_spatial_container.global_transform * p_placeforms[i][2]


func _remove_mesh_instance(p_idx: int):
	var buffer = RenderingServer.multimesh_get_buffer(_RID_multimesh)
	var instance_count = RenderingServer.multimesh_get_instance_count(_RID_multimesh)

	# TODO: this can probably be sped up if done in-place in C++
	#		GDScript was not tested, but I don't expect it to be fast at this sort of thing
	if p_idx == 0:
		buffer = buffer.slice(12)
	elif p_idx == instance_count - 1:
		buffer = buffer.slice(0, -12)
	else:
		buffer = buffer.slice(0, p_idx * 12) + buffer.slice((p_idx + 1) * 12)

	RenderingServer.multimesh_allocate_data(_RID_multimesh, instance_count - 1, RenderingServer.MULTIMESH_TRANSFORM_3D, false, false)
	RenderingServer.multimesh_set_buffer(_RID_multimesh, buffer)


func _remove_spatial_instance(p_idx: int):
	_spawned_spatial_container.remove_child(_spawned_spatial_container.get_child(p_idx))


func _set_mesh_instance(p_idx: int, p_placeform: Array):
	RenderingServer.multimesh_instance_set_transform(_RID_multimesh, p_idx, p_placeform[2])


func _set_spatial_instance(p_idx: int, p_placeform: Array):
	_spawned_spatial_container.get_child(p_idx).global_transform = _spawned_spatial_container.global_transform * p_placeform[2]
