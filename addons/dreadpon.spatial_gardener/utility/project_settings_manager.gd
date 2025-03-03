@tool


#-------------------------------------------------------------------------------
# Manages adding all plugin project settings
#-------------------------------------------------------------------------------


const Globals = preload("globals.gd")
const FunLib = preload("fun_lib.gd")
const Logger = preload("logger.gd")




# Add all settings for this plugin
static func add_plugin_project_settings():
	
	
	# Remove settings from the previous plugin version
	if ProjectSettings.has_setting("dreadpons_spatial_gardener/input_and_ui/brush_property_edit_button"):
		ProjectSettings.clear("dreadpons_spatial_gardener/input_and_ui/brush_property_edit_button")
	if ProjectSettings.has_setting("dreadpons_spatial_gardener/input_and_ui/brush_property_edit_modifier_key"):
		ProjectSettings.clear("dreadpons_spatial_gardener/input_and_ui/brush_property_edit_modifier_key")
	if ProjectSettings.has_setting("dreadpons_spatial_gardener/input_and_ui/brush_size_slider_max_value"):
		ProjectSettings.clear("dreadpons_spatial_gardener/input_and_ui/brush_size_slider_max_value")
	
	# Painting
	add_project_setting(
		"dreadpons_spatial_gardener/painting/projection_raycast_margin",
		0.1,
		TYPE_FLOAT)
	add_project_setting(
		"dreadpons_spatial_gardener/painting/simplify_projection_frustum",
		true,
		TYPE_BOOL)
	
	# Input and UI
	add_project_setting(
		"dreadpons_spatial_gardener/input_and_ui/greenhouse_ui_enable_undo_redo",
		true,
		TYPE_BOOL)
	add_project_setting(
		"dreadpons_spatial_gardener/input_and_ui/greenhouse_thumbnail_scale",
		1.0,
		TYPE_FLOAT)
	add_project_setting_globals_enum(
		"dreadpons_spatial_gardener/input_and_ui/brush_prop_edit_button",
		Globals.MouseButton.MOUSE_BUTTON_XBUTTON1, Globals.MouseButton)
	add_project_setting_globals_enum(
		"dreadpons_spatial_gardener/input_and_ui/brush_prop_edit_modifier",
		Globals.KeyboardKey.KEY_SHIFT, Globals.KeyboardKey)
	add_project_setting_globals_enum(
		"dreadpons_spatial_gardener/input_and_ui/brush_overlap_mode_button",
		Globals.KeyboardKey.KEY_QUOTELEFT, Globals.KeyboardKey)
	add_project_setting_globals_enum(
		"dreadpons_spatial_gardener/input_and_ui/focus_painter_key",
		Globals.KeyboardKey.KEY_Q, Globals.KeyboardKey)
	add_project_setting(
		"dreadpons_spatial_gardener/input_and_ui/brush_volume_size_slider_max_value",
		100.0,
		TYPE_FLOAT)
	add_project_setting(
		"dreadpons_spatial_gardener/input_and_ui/brush_projection_size_slider_max_value",
		1000.0,
		TYPE_FLOAT)
	add_project_setting(
		"dreadpons_spatial_gardener/input_and_ui/plant_max_distance_slider_max_value",
		1000.0,
		TYPE_FLOAT)
	add_project_setting(
		"dreadpons_spatial_gardener/input_and_ui/plant_kill_distance_slider_max_value",
		2000.0,
		TYPE_FLOAT)
	add_project_setting(
		"dreadpons_spatial_gardener/input_and_ui/plant_density_slider_max_value",
		2000.0,
		TYPE_FLOAT)
	add_project_setting(
		"dreadpons_spatial_gardener/input_and_ui/octree_min_node_size_slider_max_value",
		500.0,
		TYPE_FLOAT)
	
	# Plugin
	add_project_setting(
		"dreadpons_spatial_gardener/plugin/scan_for_outdated_scenes",
		true,
		TYPE_BOOL)
	add_project_setting(
		"dreadpons_spatial_gardener/plugin/is_threaded_LOD_update",
		true,
		TYPE_BOOL)
	add_project_setting(
		"dreadpons_spatial_gardener/plugin/use_precise_LOD_distances",
		true,
		TYPE_BOOL)
	add_project_setting(
		"dreadpons_spatial_gardener/plugin/use_precise_camera_frustum",
		true,
		TYPE_BOOL)
	ProjectSettings.set_restart_if_changed("dreadpons_spatial_gardener/plugin/is_threaded_LOD_update", true)
	ProjectSettings.set_restart_if_changed("dreadpons_spatial_gardener/plugin/use_precise_LOD_distances", true)
	ProjectSettings.set_restart_if_changed("dreadpons_spatial_gardener/plugin/use_precise_camera_frustum", true)
	
	# Debug
	add_project_setting_globals_enum(
		"dreadpons_spatial_gardener/debug/dump_editor_tree_key",
		Globals.KeyboardKey.KEY_NONE, Globals.KeyboardKey)
	add_project_setting_globals_enum(
		"dreadpons_spatial_gardener/debug/dump_all_octrees_key",
		Globals.KeyboardKey.KEY_NONE, Globals.KeyboardKey)
	add_project_setting(
		"dreadpons_spatial_gardener/debug/arborist_log_lifecycle",
		false,
		TYPE_BOOL)
	add_project_setting(
		"dreadpons_spatial_gardener/debug/octree_log_lifecycle",
		false,
		TYPE_BOOL)
	add_project_setting(
		"dreadpons_spatial_gardener/debug/brush_placement_area_log_grid",
		false,
		TYPE_BOOL)
	add_project_setting(
		"dreadpons_spatial_gardener/debug/input_field_resource_log_prop_actions",
		false,
		TYPE_BOOL)
	add_project_setting(
		"dreadpons_spatial_gardener/debug/debug_viewer_octree_member_size",
		2.0,
		TYPE_FLOAT)
	add_project_setting(
		"dreadpons_spatial_gardener/debug/stroke_handler_debug_draw",
		false,
		TYPE_BOOL)
	# NOTE: this was removed because users shouldn't need acces to this variable, it's for internal and testing use only
	#add_project_setting(
		#"dreadpons_spatial_gardener/debug/force_readable_node_names",
		#false,
		#TYPE_BOOL)
	#ProjectSettings.set_restart_if_changed("dreadpons_spatial_gardener/debug/force_readable_node_names", true)
	
	# Saving settings
	var err: int = ProjectSettings.save()
	if err:
		var logger = Logger.get_for_string("ProjectSettingsManager")
		logger.error("Encountered error %s when saving project settings" % [Globals.get_err_message(err)])


# Shorthand for adding enum setting and generating it's info
static func add_project_setting_globals_enum(setting_name:String, default_value:int, enum_dict:Dictionary):
	add_project_setting(
		setting_name,
		Globals.enum_to_index(default_value, enum_dict),
		TYPE_INT, PROPERTY_HINT_ENUM,
		FunLib.make_hint_string(enum_dict.keys()))


# Shorthand for adding a setting, setting it's info and initial value
static func add_project_setting(setting_name:String, default_value, type:int, hint:int = PROPERTY_HINT_NONE, hintString:String = ""):
	var setting_info: Dictionary = {
		"name": setting_name,
		"type": type,
		"hint": hint,
		"hint_string": hintString
	}
	
	if !ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, default_value)
	ProjectSettings.add_property_info(setting_info)
	ProjectSettings.set_initial_value(setting_name, default_value)
