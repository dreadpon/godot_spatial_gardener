@tool
extends Resource


#-------------------------------------------------------------------------------
# Handles managing OctreeManager objects and changes applied when painting
# Instigates updates to OctreeManager MutliMeshInstance (MMI) objects
# To show the correct LOD variant when moving closer/further to plants
#-------------------------------------------------------------------------------

# It's worth considering to split this object into mutliple:
	# Octree management
	# Updating positions of individual plants (through painting)
	# Threaded updates to LODs (if possible)
# However, these functions are very closely related, so maybe I'm overthinking this


const Logger = preload("../utility/logger.gd")
const Globals = preload("../utility/globals.gd")
const FunLib = preload("../utility/fun_lib.gd")
const Greenhouse_Plant = preload("../greenhouse/greenhouse_plant.gd")
const Toolshed_Brush = preload("../toolshed/toolshed_brush.gd")
const PaintingChanges = preload("painting_changes.gd")
const MMIOctreeManager = preload("mmi_octree/mmi_octree_manager.gd")
const UndoRedoInterface = preload("../utility/undo_redo_interface.gd")

const StrokeHandler = preload("stroke_handler/stroke_handler.gd")
const SH_Paint = preload("stroke_handler/sh_paint.gd")
const SH_Erase = preload("stroke_handler/sh_erase.gd")
const SH_Single = preload("stroke_handler/sh_single.gd")
const SH_Reapply = preload("stroke_handler/sh_reapply.gd")
const SH_Manual = preload("stroke_handler/sh_manual.gd")

var gardener_root:Node3D = null
var octree_managers:Array

var gardening_collision_mask:int = 0

# A manual override fot the camera (mainly used in Editor)
var active_camera_override:Camera3D = null

var active_stroke_handler:StrokeHandler = null
var active_painting_changes:PaintingChanges = null

# Threading LOD updates is not working for some reason. Gives error "Condition "!multimesh" is true." when closing a scene
# This might be related to https://github.com/godotengine/godot/pull/54650
# Possibly, there are some leftover references after closing a scene and idk how I'm supposed to clean them up
#var mutex_placement:Mutex = null
#var thread_instance_placement:Thread
#var semaphore_instance_placement:Semaphore
#var exit_instance_placement:bool
#var done_instance_placement:bool

var _undo_redo = null

var debug_redraw_requested_managers:Array = []

var logger = null


signal req_debug_redraw(octree_managers, requested_indexes)
signal member_count_updated(octree_index, new_count)




#-------------------------------------------------------------------------------
# Lifecycle and initialization
#-------------------------------------------------------------------------------


func _init():
	set_meta("class", "Arborist")
	logger = Logger.get_for(self)



func init_with_gardeener_root(p_gardener_root: Node3D):
	gardener_root = p_gardener_root
	FunLib.free_children(gardener_root)
	
	for octree_manager in octree_managers:
		octree_manager.restore_after_load(gardener_root)

#	thread_instance_placement = Thread.new()
#	mutex_placement = Mutex.new()
#	semaphore_instance_placement = Semaphore.new()
#
#	exit_instance_placement = false
#	done_instance_placement = true
#
#	thread_instance_placement.start(Callable(self,"thread_update_LODs"))


# func _notification(what):
# 	match what:
# 		NOTIFICATION_PREDELETE:
# 			for octree_manager in octree_managers:
# 				octree_manager.free_refs(true)
			
			# This is... weird
			# Apparently I need to free any Resources that are left after closing a scene
			# I'm not exactly sure why
			# And it *might* be destructive to do so in editor
			#if Engine.is_editor_hint(): return
			#for octree_manager in octree_managers:
				#octree_manager.destroy()
		#	mutex_placement.lock()
		#	exit_instance_placement = true
		#	done_instance_placement = false
		#	mutex_placement.unlock()
		#
		#	semaphore_instance_placement.post()
		#	thread_instance_placement.wait_to_finish()
		#
		#	thread_instance_placement = null
		#	mutex_placement = null
		#	semaphore_instance_placement = null


# Free/nullify all references that may cause memory leaks
# NOTE: we assume these refs are recreated whenever the tree is entered again
func free_circular_refs():
	for octree_manager in octree_managers:
		octree_manager.free_circular_refs()
	gardener_root = null


# Restore all references might have been freed in free_circular_refs()
func restore_circular_refs(p_gardener_root: Node3D):
	gardener_root = p_gardener_root
	for octree_manager in octree_managers:
		octree_manager.restore_circular_refs(gardener_root)


# Expected to be called inside or after a parent's _ready()
# Restore all OctreeManager objects after load
# Create missing ones
# TODO: 1.3.4 doesn't seem to actually update instances to plant meshes/spatials???
func init_with_greenhouse(plant_states):
	debug_print_lifecycle("verifying for plant_states: " + str(plant_states))
	
	for plant_index in range(0, plant_states.size()):
		if octree_managers.size() - 1 >= plant_index:
			_setup_octree_manager(plant_states[plant_index], plant_index)
		else:
			add_plant_octree_manager(plant_states[plant_index], plant_index)


func propagate_transform(global_transform: Transform3D):
	for octree_manager in octree_managers:
		octree_manager.propagate_transform(global_transform)




#-------------------------------------------------------------------------------
# Management of plant OctreeManager objects
#-------------------------------------------------------------------------------


# Instigate the OctreeManager adding process in response to an external signal
func on_plant_added(plant_state, plant_index:int):
	debug_print_lifecycle("plant: %s added at plant_index %d" % [str(plant_state), plant_index])
	add_plant_octree_manager(plant_state, plant_index)
	request_debug_redraw_from_index(plant_index)
	call_deferred("emit_member_count", plant_index)


# Instigate the OctreeManager removal process in response to an external signal
func on_plant_removed(plant_state, plant_index:int):
	debug_print_lifecycle("plant: %s removed at plant_index %d" % [str(plant_state), plant_index])
	remove_plant_octree_manager(plant_state, plant_index)
	request_debug_redraw_from_index(plant_index)


# Up-to-date LOD variants of an OctreeManager
func on_LOD_variant_added(plant_index:int, mesh_index:int, LOD_variant):
	debug_print_lifecycle("LOD Variant: %s added at plant_index %d and mesh_index %d" % [str(LOD_variant), plant_index, mesh_index])
	var octree_manager:MMIOctreeManager = octree_managers[plant_index]
	octree_manager.insert_LOD_variant(LOD_variant, mesh_index)


# Up-to-date LOD variants of an OctreeManager
func on_LOD_variant_removed(plant_index:int, mesh_index:int):
	debug_print_lifecycle("LOD Variant: removed at plant_index %d and mesh_index %d" % [plant_index, mesh_index])
	var octree_manager:MMIOctreeManager = octree_managers[plant_index]
	octree_manager.remove_LOD_variant(mesh_index)


# Up-to-date LOD variants of an OctreeManager
func on_LOD_variant_set(plant_index:int, mesh_index:int, LOD_variant):
	debug_print_lifecycle("LOD Variant: %s set at plant_index %d and mesh_index %d" % [str(LOD_variant), plant_index, mesh_index])
	var octree_manager:MMIOctreeManager = octree_managers[plant_index]
	octree_manager.set_LOD_variant(LOD_variant, mesh_index)


# Up-to-date LOD variants of an OctreeManager
func on_LOD_variant_prop_changed_spawned_spatial(plant_index:int, mesh_index:int, LOD_variant):
	debug_print_lifecycle("LOD Variant: %s spawned spatial changed at plant_index %d and mesh_index %d" % [str(LOD_variant), plant_index, mesh_index])
	var octree_manager:MMIOctreeManager = octree_managers[plant_index]
	octree_manager.on_lod_variant_spatial_changed(mesh_index)


func on_LOD_variant_prop_changed_mesh(plant_index:int, mesh_index:int, LOD_variant):
	debug_print_lifecycle("LOD Variant: %s mesh changed at plant_index %d and mesh_index %d" % [str(LOD_variant), plant_index, mesh_index])
	var octree_manager:MMIOctreeManager = octree_managers[plant_index]
	octree_manager.on_lod_variant_mesh_changed(mesh_index)


func on_LOD_variant_prop_changed_cast_shadow(plant_index:int, mesh_index:int, LOD_variant):
	debug_print_lifecycle("LOD Variant: %s cast shadow changed at plant_index %d and mesh_index %d" % [str(LOD_variant), plant_index, mesh_index])
	var octree_manager:MMIOctreeManager = octree_managers[plant_index]
	octree_manager.on_lod_variant_shadow_changed(mesh_index)


# Initialize an OctreeManager for a given plant
func add_plant_octree_manager(plant_state, plant_index:int):
	var octree_manager:MMIOctreeManager = MMIOctreeManager.new()
	octree_manager.init_octree(
		plant_state.plant.mesh_LOD_max_capacity, plant_state.plant.mesh_LOD_min_size,
		Vector3.ZERO, gardener_root, plant_state.plant.mesh_LOD_min_size)
	octree_managers.insert(plant_index, octree_manager)
	
	_setup_octree_manager(plant_state, plant_index)

	for mesh_index in range (0, plant_state.plant.mesh_LOD_variants.size()):
		var LOD_variant = plant_state.plant.mesh_LOD_variants[mesh_index]
		octree_manager.insert_LOD_variant(LOD_variant, mesh_index)


func _setup_octree_manager(plant_state, plant_index:int):
	var octree_manager:MMIOctreeManager = octree_managers[plant_index]
	octree_manager.LOD_max_distance = plant_state.plant.mesh_LOD_max_distance
	octree_manager.LOD_kill_distance = plant_state.plant.mesh_LOD_kill_distance

	var LOD_variant
	for mesh_index in range(0, min(plant_state.plant.mesh_LOD_variants.size(), octree_manager.LOD_variants.size())):
		LOD_variant = plant_state.plant.mesh_LOD_variants[mesh_index]
		octree_manager.set_LOD_variant(LOD_variant, mesh_index)

	if plant_state.plant.mesh_LOD_variants.size() > octree_manager.LOD_variants.size():
		for mesh_index in range(octree_manager.LOD_variants.size(), plant_state.plant.mesh_LOD_variants.size()):
			LOD_variant = plant_state.plant.mesh_LOD_variants[mesh_index]
			octree_manager.insert_LOD_variant(LOD_variant, mesh_index)
	elif octree_manager.LOD_variants.size() > plant_state.plant.mesh_LOD_variants.size():
		for mesh_index in range(plant_state.plant.mesh_LOD_variants.size(), octree_manager.LOD_variants.size()):
			octree_manager.remove_LOD_variant(mesh_index)

	connect_octree_manager(octree_manager)


# Remove an OctreeManager for a given plant
func remove_plant_octree_manager(plant_state, plant_index:int):
	var octree_manager:MMIOctreeManager = octree_managers[plant_index]
	disconnect_octree_manager(octree_manager)
	octree_manager.free_refs(true)
	octree_managers.remove_at(plant_index)


# A request to reconfigure an octree
func reconfigure_octree(plant_state, plant_index:int):
	var octree_manager:MMIOctreeManager = octree_managers[plant_index]
	octree_manager.rebuild_octree(plant_state.plant.mesh_LOD_max_capacity, plant_state.plant.mesh_LOD_min_size)


# A request to recenter an octree
func recenter_octree(plant_state, plant_index:int):
	var octree_manager:MMIOctreeManager = octree_managers[plant_index]
	octree_manager.recenter_octree()


# Connect all OctreeManager signals
func connect_octree_manager(octree_manager:MMIOctreeManager):
	if !octree_manager.req_debug_redraw.is_connected(on_req_debug_redraw):
		octree_manager.req_debug_redraw.connect(on_req_debug_redraw.bind(octree_manager))


# Disconnect all OctreeManager signals
func disconnect_octree_manager(octree_manager:MMIOctreeManager):
	if octree_manager.req_debug_redraw.is_connected(on_req_debug_redraw):
		octree_manager.req_debug_redraw.disconnect(on_req_debug_redraw)




#-------------------------------------------------------------------------------
# Setting/updating variables to outside signals
#-------------------------------------------------------------------------------


# To be called by a signal from Greenhouse_PlantState -> Gardener -> Arborist
func update_plant_LOD_max_distance(plant_index, val):
	var octree_manager:MMIOctreeManager = octree_managers[plant_index]
	octree_manager.LOD_max_distance = val


# To be called by a signal from Greenhouse_PlantState -> Gardener -> Arborist
func update_plant_LOD_kill_distance(plant_index, val):
	var octree_manager:MMIOctreeManager = octree_managers[plant_index]
	octree_manager.LOD_kill_distance = val


# To be called by a signal from Gardener -> Arborist
func set_gardening_collision_mask(_gardening_collision_mask):
	gardening_collision_mask = _gardening_collision_mask




#-------------------------------------------------------------------------------
# Application of brushes and transform generation
#-------------------------------------------------------------------------------


# Create PaintingChanges and a StrokeHandler for this specific brush stroke
func on_stroke_started(brush:Toolshed_Brush, plant_states:Array):
	var space_state := gardener_root.get_world_3d().direct_space_state
	var camera = get_camera_3d()
	active_painting_changes = PaintingChanges.new()
	match brush.behavior_brush_type:
		brush.BrushType.PAINT:
			active_stroke_handler = SH_Paint.new(brush, plant_states, octree_managers, space_state, camera, gardening_collision_mask)
		brush.BrushType.ERASE:
			active_stroke_handler = SH_Erase.new(brush, plant_states, octree_managers, space_state, camera, gardening_collision_mask)
		brush.BrushType.SINGLE:
			active_stroke_handler = SH_Single.new(brush, plant_states, octree_managers, space_state, camera, gardening_collision_mask)
		brush.BrushType.REAPPLY:
			active_stroke_handler = SH_Reapply.new(brush, plant_states, octree_managers, space_state, camera, gardening_collision_mask)
		_:
			active_stroke_handler = StrokeHandler.new(brush, plant_states, octree_managers, space_state, camera, gardening_collision_mask)
	
	debug_print_lifecycle("Stroke %s started" % [active_stroke_handler.get_meta("class")])


# Draw instances at the new brush position
# And collect them all into one PaintingChanges object
func on_stroke_updated(brush_data:Dictionary):
	assert(active_stroke_handler)
	assert(active_painting_changes)
	
	debug_print_lifecycle("Stroke %s updating..." % [active_stroke_handler.get_meta("class")])
	var msec_start = FunLib.get_msec()
	
#	mutex_placement.lock()
	var changes = active_stroke_handler.get_stroke_update_changes(brush_data, gardener_root.global_transform)
	apply_stroke_update_changes(changes)
#	mutex_placement.unlock()
	active_painting_changes.append_changes(changes)
	
	var msec_end = FunLib.get_msec()
	debug_print_lifecycle("Total stroke %s update took: %s" % [active_stroke_handler.get_meta("class"), FunLib.msec_to_time(msec_end - msec_start)])


# Use collected PaintingChanges to add UndoRedo actions
func on_stroke_finished():
	assert(active_stroke_handler)
	assert(active_painting_changes)
	
	UndoRedoInterface.create_action(_undo_redo, "Apply Arborist MMI changes", 0, false, self)
	UndoRedoInterface.add_do_method(_undo_redo, _action_apply_changes.bind(active_painting_changes))
	UndoRedoInterface.add_undo_method(_undo_redo, _action_apply_changes.bind(active_painting_changes.pop_opposite()))
	
	# We toggle this flag to avoid reapplying already commited changes all over again
	UndoRedoInterface.commit_action(_undo_redo, false)
	
	debug_print_lifecycle("Stroke %s finished, total changes made: %d" % [active_stroke_handler.get_meta("class"), active_painting_changes.changes.size()])
	
	active_stroke_handler = null
	active_painting_changes = null


# A wrapper for applying changes to avoid reaplying UndoRedo actions on commit_action()
func _action_apply_changes(changes):
#	mutex_placement.lock()
	apply_stroke_update_changes(changes)
#	mutex_placement.unlock()




#-------------------------------------------------------------------------------
# Updating OctreeManager objects
#-------------------------------------------------------------------------------


# Replace LOD_Variants inside of a shared array owned by this OctreeManager
# func refresh_octree_shared_LOD_variants(plant_index:int, LOD_variants:Array):
# 	if octree_managers.size() > plant_index:
# 		octree_managers[plant_index].set_LOD_variants(LOD_variants)


# Add changes to corresponding OctreeManager queues
# Then process them all at once
func apply_stroke_update_changes(changes:PaintingChanges):
	debug_print_lifecycle("	Applying %d stroke changes" % [changes.changes.size()])
	var msec_start = FunLib.get_msec()
	
	var affected_octree_managers := []
	
	for change in changes.changes:
		var octree_manager:MMIOctreeManager = octree_managers[change.at_index]
		
		match change.change_type:
			0:
				octree_manager.queue_placeforms_add(change.new_val)
			1:
				octree_manager.queue_placeforms_remove(change.new_val)
			2:
				octree_manager.queue_placeforms_set(change.new_val)
		
		if !affected_octree_managers.has(change.at_index):
			affected_octree_managers.append(change.at_index)
	
	for index in affected_octree_managers:
		var octree_manager = octree_managers[index]
		octree_manager.process_queues()
		emit_member_count(index)
	
	var msec_end = FunLib.get_msec()
	debug_print_lifecycle("	Applying stroke changes took: %s" % [FunLib.msec_to_time(msec_end - msec_start)])


func emit_total_member_count():
	for i in range(0, octree_managers.size()):
		emit_member_count(i)


func emit_member_count(octree_index:int):
	member_count_updated.emit(octree_index, octree_managers[octree_index].root_octree_node.get_nested_member_count())


func update(delta):
#	try_update_LODs()
	if gardener_root.visible:
		update_LODs()
		request_debug_redraw()


# Trigger a threaded LOD update
#func try_update_LODs():
#	var should_post = false
#
#	mutex_placement.lock()
#	if done_instance_placement:
#		done_instance_placement = false
#		should_post = true
#	mutex_placement.unlock()
#
#	if should_post:
#		semaphore_instance_placement.post()


# A function that carries out threaded LOD updates
#func thread_update_LODs(arg = null):
#	while true:
#		semaphore_instance_placement.wait()
#
#		var should_exit = false
#		mutex_placement.lock()
#		if exit_instance_placement:
#			should_exit = true
#		mutex_placement.unlock()
#		if should_exit: break
#
#		mutex_placement.lock()
#		update_LODs()
#		done_instance_placement = true
#		mutex_placement.unlock()


# Instigate LOD updates in OctreeManager objects
func update_LODs():
	var camera_to_use:Camera3D = get_camera_3d()
	if camera_to_use:
		var camera_pos := camera_to_use.global_transform.origin
		for octree_manager in octree_managers:
			octree_manager.update_LODs(camera_pos, gardener_root.global_transform)
	# This exists to properly render instances in editor even if there is no forwarded_input()
	else:
		for octree_manager in octree_managers:
			octree_manager.update_LODs_no_camera()


# Add instances as a batch (mostly, as a result of importing Greenhouse data)
func batch_add_instances(placeforms: Array, plant_idx: int):
	active_painting_changes = PaintingChanges.new()
	active_stroke_handler = SH_Manual.new()
	
	for placeform in placeforms:
		active_stroke_handler.add_instance_placeform(placeform, plant_idx, active_painting_changes)
	
	apply_stroke_update_changes(active_painting_changes)
	on_stroke_finished()




#-------------------------------------------------------------------------------
# Input
#-------------------------------------------------------------------------------


func forward_input(event):
	if is_instance_of(event, InputEventKey) && !event.pressed:
		if event.keycode == debug_get_dump_tree_key():
			for octree_manager in octree_managers:
				logger.info(octree_manager.root_octree_node.debug_dump_tree())




#-------------------------------------------------------------------------------
# Utility
#-------------------------------------------------------------------------------


# A hack to get editor camera
# active_camera_override should be set by a Gardener
# In-game just gets an active viewport's camera
func get_camera_3d():
	if is_instance_valid(active_camera_override):
		return active_camera_override
	else:
		active_camera_override = null
		return gardener_root.get_viewport().get_camera_3d()




#-------------------------------------------------------------------------------
# Property export
#-------------------------------------------------------------------------------


func _get(property):
	match property:
		"octree_managers":
			return octree_managers
	return null


func _set(property, val):
	var return_val = true
	
	match property:
		"octree_managers":
			octree_managers = val
		_:
			return_val = false
	
	return return_val


func _get_property_list():
	var props := [
		{
			"name": "octree_managers",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
	]
	return props




#-------------------------------------------------------------------------------
# Debug
#-------------------------------------------------------------------------------


# A wrapper to request debug redraw for a specific OctreeManager
func request_debug_redraw_from_index(plant_index):
	for index in range(plant_index, octree_managers.size()):
		on_req_debug_redraw(octree_managers[index])


# Add an OctreeManager to the debug redraw waiting list
func on_req_debug_redraw(octree_manager:MMIOctreeManager):
	if debug_redraw_requested_managers.has(octree_manager): return
	debug_redraw_requested_managers.append(octree_manager)


# Request a debug redraw for all OctreeManager objects in a waiting list using a signal
# We manually get all indexes here instead of when an OctreeManager is added to the waiting list
# Because we expect the order of managers might change and indexes will become inaccurate
# Typically called from _process()
func request_debug_redraw():
	if debug_redraw_requested_managers.is_empty(): return
	
	var requested_indexes := []
	for octree_manager in debug_redraw_requested_managers:
		requested_indexes.append(octree_managers.find(octree_manager))
	
	if !requested_indexes.is_empty():
		req_debug_redraw.emit(octree_managers)
	debug_redraw_requested_managers = []


func debug_get_dump_tree_key():
	var key = FunLib.get_setting_safe("dreadpons_spatial_gardener/debug/dump_all_octrees_key", 0)
	return Globals.index_to_enum(key, Globals.KeyboardKey)


func debug_print_lifecycle(string:String):
	if !FunLib.get_setting_safe("dreadpons_spatial_gardener/debug/arborist_log_lifecycle", false): return
	logger.info(string)
