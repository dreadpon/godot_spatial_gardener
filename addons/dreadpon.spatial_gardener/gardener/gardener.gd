@tool
extends Node3D


#-------------------------------------------------------------------------------
# Manages the lifecycles and connection of all components:
# Greenhouse plants, Toolshed brushes, Painter controller
# And the Arborist plant placement manager
#
# A lot of these connections go through the Gardener
# Because some signal receivers need additional data the signal senders don't know about
# E.g. painter doesn't know about plant states, but arborist needs them to apply painting changes
#-------------------------------------------------------------------------------


const FunLib = preload("../utility/fun_lib.gd")
const Logger = preload("../utility/logger.gd")
const Defaults = preload("../utility/defaults.gd")
const Greenhouse = preload("../greenhouse/greenhouse.gd")
const Toolshed = preload("../toolshed/toolshed.gd")
const Painter = preload("painter.gd")
const Arborist = preload("../arborist/arborist.gd")
const DebugViewer = preload("debug_viewer.gd")
const Baker = preload("baker.gd")
const UI_SidePanel_SCN = preload("../controls/side_panel/ui_side_panel.tscn")
const UI_SidePanel = preload("../controls/side_panel/ui_side_panel.gd")
const Globals = preload("../utility/globals.gd")
const DataImportExport = preload("data_import_export.gd")
const Transplanter = preload("../transplanter/transplanter.gd")

const PropAction = preload("../utility/input_field_resource/prop_action.gd")
const PA_PropSet = preload("../utility/input_field_resource/pa_prop_set.gd")
const PA_PropEdit = preload("../utility/input_field_resource/pa_prop_edit.gd")
const PA_ArrayInsert = preload("../utility/input_field_resource/pa_array_insert.gd")
const PA_ArrayRemove = preload("../utility/input_field_resource/pa_array_remove.gd")
const PA_ArraySet = preload("../utility/input_field_resource/pa_array_set.gd")



var plugin_version: String = ""
var storage_version: int = 0

# file_management
var garden_work_directory:String : set = set_garden_work_directory
# gardening
var gardening_collision_mask := pow(2, 0) : set = set_gardening_collision_mask

var initialized_for_edit:bool = false : set = set_initialized_for_edit
var is_edited: bool = false

var toolshed:Toolshed = null
var greenhouse:Greenhouse = null
var painter:Painter = null
var arborist:Arborist = Arborist.new()
var transplanter:Transplanter = null
var debug_viewer:DebugViewer = null
var baker:Baker = null

var _resource_previewer = null
var _base_control:Control = null
var _undo_redo = null

var _side_panel:UI_SidePanel = null
var ui_category_brushes:Control = null
var ui_category_plants:Control = null

var painting_node:Node3D = null

var logger = null
var forward_input_events:bool = true


signal changed_initialized_for_edit(state)
signal greenhouse_prop_action_executed(prop_action, final_val)




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init():
	set_meta("class", "Gardener")
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)
	set_notify_transform(true)
	_setup_configuration_statics()


func _setup_configuration_statics():
	Globals.is_threaded_LOD_update = 		FunLib.get_setting_safe("dreadpons_spatial_gardener/plugin/is_threaded_LOD_update", true)
	Globals.use_precise_LOD_distances = 	FunLib.get_setting_safe("dreadpons_spatial_gardener/plugin/use_precise_LOD_distances", true)
	Globals.use_precise_camera_frustum = 	FunLib.get_setting_safe("dreadpons_spatial_gardener/plugin/use_precise_camera_frustum", true)


# Update plugin/storage versions that might have been stored inside a .tscn file for this Gardener
# In case it was created in an older version of this plugin
func update_plugin_ver():
	plugin_version = get_plugin_ver()
	storage_version = get_storage_ver()


static func get_plugin_ver():
	return '1.4.1'


static func get_storage_ver():
	return 4


func _ready():
	update_plugin_ver()
	
	logger = Logger.get_for(self, name)
	
	painting_node = Node3D.new()
	add_child(painting_node, true, Node.INTERNAL_MODE_FRONT)
	
	debug_viewer = DebugViewer.new()
	add_child(debug_viewer, true, Node.INTERNAL_MODE_FRONT)
	
	baker = Baker.new()
	add_child(baker, true, Node.INTERNAL_MODE_FRONT)
	
	init_painter()
	init_transplanter()
	
	if !is_instance_valid(arborist):
		push_warning("Arborist invalid. This should never happen. Creating a new one...")
		arborist = Arborist.new()
	
	reload_resources()
	init_arborist()
	set_gardening_collision_mask(gardening_collision_mask)


func _enter_tree() -> void:
	arborist.restore_circular_refs(self)
	arborist.start_threaded_processes()


func _exit_tree():
	# NOTE: we assume these refs are recreated whenever the tree is entered again
	arborist.free_circular_refs()
	arborist.finish_threaded_processes()
	
	if !Engine.is_editor_hint(): return
	
	_apply_changes()
	stop_editing()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			_propagate_transform()
		NOTIFICATION_VISIBILITY_CHANGED:
			_propagate_visibility()


func _propagate_transform():
	arborist.propagate_transform(global_transform)


func _propagate_visibility():
	arborist.propagate_visibility(is_visible_in_tree())


func _process(delta):
	arborist.update(delta)
	painter.update(delta)
	transplanter.update(delta)


# TODO: this will be irrelevant after we move Greenhouse to be saved with its Gardener
#		and Toolshed shared for all Gardeners and stored in .godot folder
func _apply_changes():
	if !Engine.is_editor_hint(): return
	if !FunLib.is_dir_valid(garden_work_directory): return
	
	save_toolshed()
	save_greenhouse()
	toolshed.set_undo_redo(_undo_redo)
	greenhouse.set_undo_redo(_undo_redo)


func _on_child_entered_tree(child: Node):
	update_configuration_warnings.call_deferred()


func _on_child_exiting_tree(child: Node):
	update_configuration_warnings.call_deferred()




#-------------------------------------------------------------------------------
# Input
#-------------------------------------------------------------------------------


func forwarded_input(camera, event):
	if !forward_input_events: return false
	
	var handled = painter.forwarded_input(camera, event)
	if !handled:
		handled = transplanter.forwarded_input(camera, event)
	if !handled:
		handled = toolshed.forwarded_input(camera, event)
	if !handled:
		handled = arborist.forward_input(event)
	
	return handled


# A hack to propagate editor camera
# Should be called by plugin.gd
func propagate_camera(camera:Camera3D):
	if arborist:
		arborist.active_camera_override = camera




#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


# This is supposed to address a problem decribed in "start_gardener_edit()" of "plugin.gd"
# Instead of recalculating everything, we hope it's enough to just restore the member references
func restore_references():
	logger = Logger.get_for(self, name)
	if !Engine.is_editor_hint(): return
	
	init_painter()
	reload_resources()
	
	set_gardening_collision_mask(gardening_collision_mask)


# Initialize a Painter
# Assumed to be the first manager to initialize
func init_painter():
	painter = Painter.new(painting_node)
	painter.stroke_updated.connect(on_painter_stroke_updated)
	painter.changed_active_brush_prop.connect(on_changed_active_brush_prop)
	painter.stroke_started.connect(on_painter_stroke_started)
	painter.stroke_finished.connect(on_painter_stroke_finished)
	painter.set_brush_collision_mask(gardening_collision_mask)


# Initialize the Arborist and connect it to other objects
func init_arborist():
	arborist.init_with_gardeener_root(self)
	if greenhouse:
		reinit_arborist_with_greenhouse()
	reinit_debug_viewer_with_arborist()
	reinit_debug_viewer_with_greenhouse()


func init_transplanter():
	transplanter = Transplanter.new(self)
	transplanter.member_transformed.connect(on_transplanter_member_transformed)
	arborist.transplanted_member.connect(transplanter.on_transplanted_member)


# Initialize a Greenhouse and a Toolshed
# Rebuild UI if needed
func reload_resources():
	var last_toolshed = toolshed
	var last_greenhouse = greenhouse
	
	var created_new_toolshed := false
	var created_new_greenhouse := false
	
	if !FunLib.is_dir_valid(garden_work_directory):
		logger.warn("Skipped loading Toolshed and Greenhouse, please specify a working directory for this Gardener (%s)" % [str(self)])
	else:
		toolshed = FunLib.load_res(garden_work_directory, "toolshed.tres", false)
		greenhouse = FunLib.load_res(garden_work_directory, "greenhouse.tres", false)
	if !toolshed: 
		logger.warn("Unable to load Toolshed, created a new one")
		toolshed = Defaults.DEFAULT_TOOLSHED()
		created_new_toolshed = true
	if !greenhouse: 
		logger.warn("Unable to load Greenhouse, created a new one")
		greenhouse = Greenhouse.new()
		created_new_greenhouse = true
	
	toolshed.set_undo_redo(_undo_redo)
	greenhouse.set_undo_redo(_undo_redo)
	
	if last_toolshed:
		last_toolshed.prop_action_executed.disconnect(on_toolshed_prop_action_executed)
		last_toolshed.prop_action_executed_on_brush.disconnect(on_toolshed_prop_action_executed_on_brush)
	FunLib.ensure_signal(toolshed.prop_action_executed, on_toolshed_prop_action_executed)
	FunLib.ensure_signal(toolshed.prop_action_executed_on_brush, on_toolshed_prop_action_executed_on_brush)
	
	if last_greenhouse:
		last_greenhouse.prop_action_executed.disconnect(on_greenhouse_prop_action_executed)
		last_greenhouse.prop_action_executed_on_plant_state.disconnect(on_greenhouse_prop_action_executed_on_plant_state)
		last_greenhouse.prop_action_executed_on_plant_state_plant.disconnect(on_greenhouse_prop_action_executed_on_plant_state_plant)
		last_greenhouse.prop_action_executed_on_LOD_variant.disconnect(on_greenhouse_prop_action_executed_on_LOD_variant)
		last_greenhouse.req_octree_reconfigure.disconnect(on_greenhouse_req_octree_reconfigure)
		last_greenhouse.req_octree_recenter.disconnect(on_greenhouse_req_octree_recenter)
		last_greenhouse.req_import_plant_data.disconnect(on_greenhouse_req_import_plant_data)
		last_greenhouse.req_export_plant_data.disconnect(on_greenhouse_req_export_plant_data)
		last_greenhouse.req_import_greenhouse_data.disconnect(on_greenhouse_req_import_greenhouse_data)
		last_greenhouse.req_export_greenhouse_data.disconnect(on_greenhouse_req_export_greenhouse_data)
	FunLib.ensure_signal(greenhouse.prop_action_executed, on_greenhouse_prop_action_executed)
	FunLib.ensure_signal(greenhouse.prop_action_executed_on_plant_state, on_greenhouse_prop_action_executed_on_plant_state)
	FunLib.ensure_signal(greenhouse.prop_action_executed_on_plant_state_plant, on_greenhouse_prop_action_executed_on_plant_state_plant)
	FunLib.ensure_signal(greenhouse.prop_action_executed_on_LOD_variant, on_greenhouse_prop_action_executed_on_LOD_variant)
	FunLib.ensure_signal(greenhouse.req_octree_reconfigure, on_greenhouse_req_octree_reconfigure)
	FunLib.ensure_signal(greenhouse.req_octree_recenter, on_greenhouse_req_octree_recenter)
	FunLib.ensure_signal(greenhouse.req_import_plant_data, on_greenhouse_req_import_plant_data)
	FunLib.ensure_signal(greenhouse.req_export_plant_data, on_greenhouse_req_export_plant_data)
	FunLib.ensure_signal(greenhouse.req_import_greenhouse_data, on_greenhouse_req_import_greenhouse_data)
	FunLib.ensure_signal(greenhouse.req_export_greenhouse_data, on_greenhouse_req_export_greenhouse_data)
	
	if arborist:
		reinit_arborist_with_greenhouse()
	
	if toolshed && toolshed != last_toolshed && _side_panel:
		ui_category_brushes = toolshed.create_ui(_base_control, _resource_previewer)
		_side_panel.set_tool_ui(ui_category_brushes, 0)
	if greenhouse && greenhouse != last_greenhouse && _side_panel:
		ui_category_plants = greenhouse.create_ui(_base_control, _resource_previewer)
		_side_panel.set_tool_ui(ui_category_plants, 1)
	
	if arborist:
		arborist.emit_total_member_count()
	
	if created_new_toolshed:
		save_toolshed()
	if created_new_greenhouse:
		save_greenhouse()


# It's possible we load a different Greenhouse while an Arborist is already initialized
# So collapse that into a function
func reinit_arborist_with_greenhouse():
	if !arborist || !greenhouse:
		if !arborist: logger.warn("Arborist->Greenhouse: Arborist is not initialized!")
		if !greenhouse: logger.warn("Arborist->Greenhouse: Greenhouse is not initialized!")
		return
	# We could duplicate an array, but that's additional overhead so we assume Arborist won't change it
	arborist.init_with_greenhouse(greenhouse.greenhouse_plant_states)
	
	if !arborist.member_count_updated.is_connected(greenhouse.plant_count_updated):
		arborist.member_count_updated.connect(greenhouse.plant_count_updated)


func reinit_debug_viewer_with_greenhouse():
	if !debug_viewer || !greenhouse:
		if !debug_viewer: logger.warn("DebugViewer->Greenhouse: DebugViewer is not initialized!")
		if !greenhouse: logger.warn("DebugViewer->Greenhouse: Greenhouse is not initialized!")
		return
	
	debug_viewer.set_prop_edit_selected_plant(greenhouse.greenhouse_plant_states.find(greenhouse.selected_for_edit_resource))
	reinit_debug_draw_brush_active()


func reinit_debug_viewer_with_arborist():
	if !debug_viewer || !arborist:
		if !debug_viewer: logger.warn("DebugViewer->Arborist: DebugViewer is not initialized!")
		if !arborist: logger.warn("DebugViewer->Arborist: Arborist is not initialized!")
		return
	
	if !arborist.req_debug_redraw.is_connected(debug_viewer.request_debug_redraw):
		arborist.req_debug_redraw.connect(debug_viewer.request_debug_redraw)




#-------------------------------------------------------------------------------
# Start/stop editing lifecycle
#-------------------------------------------------------------------------------


# Start editing (painting) a scene
func start_editing(__base_control:Control, __resource_previewer, __undoRedo, __side_panel:UI_SidePanel):
	_base_control = __base_control
	_resource_previewer = __resource_previewer
	_undo_redo = __undoRedo

	_side_panel = __side_panel
	changed_initialized_for_edit.connect(_side_panel.set_main_control_state)
	
	ui_category_brushes = toolshed.create_ui(_base_control, _resource_previewer)
	ui_category_plants = greenhouse.create_ui(_base_control, _resource_previewer)
	_side_panel.set_tool_ui(ui_category_brushes, 0)
	_side_panel.set_tool_ui(ui_category_plants, 1)
	toolshed.set_undo_redo(_undo_redo)
	greenhouse.set_undo_redo(_undo_redo)

	arborist._undo_redo = _undo_redo
	baker._undo_redo = _undo_redo

#	# Making sure we and UI are on the same page (setting property values and checkboxes/tabs)
	painter_update_to_active_brush(toolshed.active_brush)
	transplanter_update_to_active_brush(toolshed.active_brush)
	_side_panel.set_main_control_state(initialized_for_edit)

	painter.start_editing()
	
	arborist.emit_total_member_count()
	is_edited = true


# Stop editing (painting) a scene
func stop_editing():
	if is_instance_valid(_side_panel):
		changed_initialized_for_edit.disconnect(_side_panel.set_main_control_state)
		_side_panel = null
	
	if is_instance_valid(painter):
		painter.stop_editing()
	is_edited = false


# We can properly start editing only when a workDirectory is set
func validate_initialized_for_edit():
	var work_directory_valid = FunLib.is_dir_valid(garden_work_directory)
	
	# Originally there were two conditions to fulfill, not just the workDirectory
	# Keeping this in case it will be needed in the future
	var _initialized_for_edit = work_directory_valid
	if initialized_for_edit != _initialized_for_edit:
		set_initialized_for_edit(_initialized_for_edit)


# Pass a request for updating a debug view menu
func up_to_date_debug_view_menu(debug_view_menu:MenuButton):
	assert(debug_viewer)
	debug_viewer.up_to_date_debug_view_menu(debug_view_menu)
	debug_viewer.request_debug_redraw(arborist.octree_managers)


# Pass a request for checking a debug view menu flag
func debug_view_flag_checked(debug_view_menu:MenuButton, flag:int):
	assert(debug_viewer)
	debug_viewer.flag_checked(debug_view_menu, flag)
	debug_viewer.request_debug_redraw(arborist.octree_managers)


func up_to_date_bake_menu(bake_menu: Button):
	assert(baker)
	assert(greenhouse)
	var plant_names := []
	for plant_state in greenhouse.greenhouse_plant_states:
		plant_names.append(plant_state.plant_label)
	baker.up_to_date_baker_menu(bake_menu, self, plant_names, _base_control, _resource_previewer)


func bake_menu_pressed(bake_menu: Button):
	assert(baker)
	up_to_date_bake_menu(bake_menu)
	baker.bake_menu_pressed(bake_menu)


func bake_requested(bake_menu: Button):
	assert(baker)
	baker.request_bake(bake_menu, self)




#-------------------------------------------------------------------------------
# Handle changes in owned properties
#-------------------------------------------------------------------------------


func set_gardening_collision_mask(val):
	gardening_collision_mask = val
	if painter:
		painter.set_brush_collision_mask(gardening_collision_mask)
	if arborist:
		arborist.set_gardening_collision_mask(gardening_collision_mask)


func set_garden_work_directory(val):
	if !val.is_empty() && !val.ends_with("/"):
		val += "/"
	
	var changed = garden_work_directory != val
	garden_work_directory = val
	
	if !Engine.is_editor_hint(): return
	# If we changed a directory, reload everything that resides there
	if changed:
		if is_inside_tree():
			reload_resources()
		validate_initialized_for_edit()


func set_initialized_for_edit(val):
	initialized_for_edit = val
	changed_initialized_for_edit.emit(initialized_for_edit)




#-------------------------------------------------------------------------------
# Handle communication with the Greenhouse
#-------------------------------------------------------------------------------


# When Greenhouse properties are changed
func on_greenhouse_prop_action_executed(prop_action:PropAction, final_val):
	if is_instance_of(prop_action, PA_ArrayInsert):
		arborist.on_plant_added(final_val[prop_action.index], prop_action.index)
		reinit_debug_draw_brush_active()
	elif is_instance_of(prop_action, PA_ArrayRemove):
		arborist.on_plant_removed(prop_action.val, prop_action.index)
		reinit_debug_draw_brush_active()
	elif is_instance_of(prop_action, PA_PropSet) && prop_action.prop == "plant_types/selected_for_edit_resource":
		debug_viewer.set_prop_edit_selected_plant(greenhouse.greenhouse_plant_states.find(final_val))
		debug_viewer.request_debug_redraw(arborist.octree_managers)
	
	greenhouse_prop_action_executed.emit(prop_action, final_val)


# When Greenhouse_PlantState properties are changed
func on_greenhouse_prop_action_executed_on_plant_state(prop_action:PropAction, final_val, plant_state):
	var plant_index = greenhouse.greenhouse_plant_states.find(plant_state)
	
	match prop_action.prop:
		"plant/plant_brush_active":
			if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
				debug_viewer.set_brush_active_plant(plant_state.plant_brush_active, plant_index)
				debug_viewer.request_debug_redraw(arborist.octree_managers)


# When Greenhouse_Plant properties are changed
func on_greenhouse_prop_action_executed_on_plant_state_plant(prop_action:PropAction, final_val, plant, plant_state):
	var plant_index = greenhouse.greenhouse_plant_states.find(plant_state)
	
	match prop_action.prop:
		"mesh/mesh_LOD_variants":
			if is_instance_of(prop_action, PA_ArrayInsert):
				var mesh_index = prop_action.index
				arborist.on_LOD_variant_added(plant_index, mesh_index, final_val[mesh_index])
			elif is_instance_of(prop_action, PA_ArrayRemove):
				var mesh_index = prop_action.index
				arborist.on_LOD_variant_removed(plant_index, mesh_index)
			elif is_instance_of(prop_action, PA_ArraySet):
				var mesh_index = prop_action.index
				arborist.on_LOD_variant_set(plant_index, mesh_index, final_val[mesh_index])
		
		"mesh/mesh_LOD_max_distance":
			if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
				arborist.update_plant_LOD_max_distance(plant_index, final_val)
		
		"mesh/mesh_LOD_kill_distance":
			if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
				arborist.update_plant_LOD_kill_distance(plant_index, final_val)


# When Greenhouse_LODVariant properties are changed
func on_greenhouse_prop_action_executed_on_LOD_variant(prop_action:PropAction, final_val, LOD_variant, plant, plant_state):
	var plant_index = greenhouse.greenhouse_plant_states.find(plant_state)
	var mesh_index = plant.mesh_LOD_variants.find(LOD_variant)
	
	match prop_action.prop:
		"mesh":
			if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
				arborist.on_LOD_variant_prop_changed_mesh(plant_index, mesh_index, final_val)
		"spawned_spatial":
			if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
				arborist.on_LOD_variant_prop_changed_spawned_spatial(plant_index, mesh_index, final_val)
		"cast_shadow":
			if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
				arborist.on_LOD_variant_prop_changed_cast_shadow(plant_index, mesh_index, final_val)


# A request to reconfigure an octree
func on_greenhouse_req_octree_reconfigure(plant, plant_state):
	if !is_edited: return
	var plant_index = greenhouse.greenhouse_plant_states.find(plant_state)
	arborist.reconfigure_octree(plant_state, plant_index)


# A request to recenter an octree
func on_greenhouse_req_octree_recenter(plant, plant_state):
	if !is_edited: return
	var plant_index = greenhouse.greenhouse_plant_states.find(plant_state)
	arborist.recenter_octree(plant_index)


# Update brush active indexes for DebugViewer
func reinit_debug_draw_brush_active():
	debug_viewer.reset_brush_active_plants()
	for plant_index in range(0, greenhouse.greenhouse_plant_states.size()):
		var plant_state = greenhouse.greenhouse_plant_states[plant_index]
		debug_viewer.set_brush_active_plant(plant_state.plant_brush_active, plant_index)
	debug_viewer.request_debug_redraw(arborist.octree_managers)




#-------------------------------------------------------------------------------
# Importing/exporting data
#-------------------------------------------------------------------------------


# A request to import plant data
func on_greenhouse_req_import_plant_data(file_path: String, plant_idx: int, replace_existing: bool):
	if !is_edited: return
	var import_export = DataImportExport.new(arborist, greenhouse)
	import_export.import_plant_data(file_path, plant_idx, replace_existing)


# A request to export plant data
func on_greenhouse_req_export_plant_data(file_path: String, plant_idx: int):
	if !is_edited: return
	var import_export = DataImportExport.new(arborist, greenhouse)
	import_export.export_plant_data(file_path, plant_idx)


# A request to import entire greenhouse data
func on_greenhouse_req_import_greenhouse_data(file_path: String, replace_existing: bool):
	if !is_edited: return
	var import_export = DataImportExport.new(arborist, greenhouse)
	import_export.import_greenhouse_data(file_path, replace_existing)


# A request to export entire greenhouse data
func on_greenhouse_req_export_greenhouse_data(file_path: String):
	if !is_edited: return
	var import_export = DataImportExport.new(arborist, greenhouse)
	import_export.export_greenhouse_data(file_path)




#-------------------------------------------------------------------------------
# Painter stroke lifecycle
#-------------------------------------------------------------------------------


func on_painter_stroke_started(brush_data:Dictionary):
	var active_brush = toolshed.active_brush
	arborist.on_stroke_started(active_brush, greenhouse.greenhouse_plant_states)


func on_painter_stroke_finished(brush_data:Dictionary):
	arborist.on_stroke_finished()


func on_painter_stroke_updated(brush_data:Dictionary):
	arborist.on_stroke_updated(brush_data)


func on_transplanter_member_transformed(changes):
	arborist.apply_member_update_changes(changes)



#-------------------------------------------------------------------------------
# Painter - Toolshed relations
#-------------------------------------------------------------------------------


# Changed active brush from Toolshed. Update the painter
func on_toolshed_prop_action_executed(prop_action:PropAction, final_val):
	assert(painter)
	assert(transplanter)
	if prop_action.prop != "brush/active_brush": return
	if !(is_instance_of(prop_action, PA_PropSet)) && !(is_instance_of(prop_action, PA_PropEdit)): return
	if final_val != toolshed.active_brush:
		logger.error("Passed final_val is not equal to toolshed.active_brush!")
		return
	
	painter_update_to_active_brush(final_val)
	transplanter_update_to_active_brush(final_val)


func painter_update_to_active_brush(active_brush):
	assert(active_brush)
	painter.queue_call_when_camera('update_all_props_to_active_brush', [active_brush])


func transplanter_update_to_active_brush(active_brush):
	assert(active_brush)
	transplanter.update_all_props_to_active_brush(active_brush)




#-------------------------------------------------------------------------------
# Quick edit for brush properties
#-------------------------------------------------------------------------------


# Property change instigated by Painter
func on_changed_active_brush_prop(prop: String, val, final:bool):
	var prop_action: PropAction = null
	if final:
		prop_action = PA_PropSet.new(prop, val)
	else:
		prop_action = PA_PropEdit.new(prop, val)
	
	if prop_action:
		toolshed.active_brush.request_prop_action(prop_action)


# Propagate active_brush property changes to Painter
func on_toolshed_prop_action_executed_on_brush(prop_action:PropAction, final_val, brush):
	assert(painter)
	if !(is_instance_of(prop_action, PA_PropSet)) && !(is_instance_of(prop_action, PA_PropEdit)): return
	if brush != toolshed.active_brush: return
	
	match prop_action.prop:
		"shape/shape_volume_size":
			painter.set_active_brush_size(final_val)
		"shape/shape_projection_size":
			painter.set_active_brush_size(final_val)
		"behavior/behavior_strength":
			painter.set_active_brush_strength(final_val)
		"behavior/behavior_overlap_mode":
			painter_update_to_active_brush(brush)
		"behavior/behavior_selection_mode":
			transplanter_update_to_active_brush(brush)
		"behavior/behavior_selection_collision_mask":
			transplanter_update_to_active_brush(brush)
		"behavior/behavior_enable_selection_preprocess":
			transplanter_update_to_active_brush(brush)




#-------------------------------------------------------------------------------
# Saving, loading and file management
#-------------------------------------------------------------------------------


func save_toolshed():
	if FunLib.is_dir_valid(garden_work_directory):
		FunLib.save_res(toolshed, garden_work_directory, "toolshed.tres")


func save_greenhouse():
	if FunLib.is_dir_valid(garden_work_directory):
		FunLib.save_res(greenhouse, garden_work_directory, "greenhouse.tres")




#-------------------------------------------------------------------------------
# Property export
#-------------------------------------------------------------------------------


# Writing this by hand THRICE for each property is honestly tiring
# Built-in Godot reflection would go a long way
func _get(property):
	match property:
		"file_management/garden_work_directory":
			return garden_work_directory
		"gardening/gardening_collision_mask":
			return gardening_collision_mask
		"arborist":
			return arborist
		"plugin_version":
			return plugin_version
		"storage_version":
			return storage_version


func _set(property, val):
	var return_val = true
	
	match property:
		"file_management/garden_work_directory":
			set_garden_work_directory(val)
		"gardening/gardening_collision_mask":
			set_gardening_collision_mask(val)
		_:
			return_val = false
	
	return return_val


func _get_property_list():
	return [
		{
			"name": "file_management/garden_work_directory",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_DIR
		},
		{
			"name": "gardening/gardening_collision_mask",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_LAYERS_3D_PHYSICS
		},
		{
			"name": "arborist",
			"type": TYPE_OBJECT,
			"usage": PROPERTY_USAGE_NO_EDITOR,
			#"hint": PROPERTY_HINT_RESOURCE_TYPE,
			#"hint_string": "Arborist"
		},
		{
			"name": "plugin_version",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_NO_EDITOR,
		},
		{
			"name": "storage_version",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_NO_EDITOR,
		},
	]


# Warning to be displayed in editor SceneTree
func _get_configuration_warnings():
	if is_instance_valid(arborist):
		return PackedStringArray()
	else:
		return PackedStringArray(["Gardener is missing a valid Arborist child", "Since it should be created automatically, try reloading a scene or recreating a Gardener"])
