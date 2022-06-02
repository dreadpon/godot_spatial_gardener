tool
extends EditorPlugin


#-------------------------------------------------------------------------------
# Handles the inception of all editor-specific processes:
# Plant creation, painting, UI
# Controls the editing lifecycle of a Gardener
#-------------------------------------------------------------------------------


const Logger = preload("utility/logger.gd")
const Globals = preload("utility/globals.gd")
const FunLib = preload("utility/fun_lib.gd")
const ProjectSettingsManager = preload("utility/project_settings_manager.gd")
const Gardener = preload("gardener/gardener.gd")
const DebugViewer = preload("gardener/debug_viewer.gd")
const UI_SidePanel = preload("controls/ui_side_panel.gd")
const ThemeAdapter = preload("controls/theme_adapter.gd")

const Greenhouse = preload("greenhouse/greenhouse.gd")
const Greenhouse_Plant = preload("greenhouse/greenhouse_plant.gd")
const Greenhouse_PlantState = preload("greenhouse/greenhouse_plant_state.gd")
const Greenhouse_LODVariant = preload("greenhouse/greenhouse_LOD_variant.gd")
const Toolshed = preload("toolshed/toolshed.gd")
const Toolshed_Brush = preload("toolshed/toolshed_brush.gd")
const PlacementTransform = preload("arborist/placement_transform.gd")

const Console_SCN = preload("utility/console/console.tscn")
const Console = preload("utility/console/console.gd")

const gardener_icon:Texture = preload("icons/gardener_icon.svg")


var side_panel_ND:UI_SidePanel = UI_SidePanel.new()
var _base_control:Control = Control.new()
var _resource_previewer = null
var control_theme:Theme = null

var toolbar:HBoxContainer = HBoxContainer.new()
var debug_view_menu:MenuButton

var active_gardener = null
var gardeners_in_tree:Array = []

var logger = null




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


# Most lifecycle functions here and later on are restricted as editor-only
# Editing plants without an editor is not currently supported
func _ready():
	# Is calling it from _ready() the correct way to use it?
	# See https://github.com/godotengine/godot/pull/9099
	# And https://github.com/godotengine/godot/issues/6869
	set_input_event_forwarding_always_enabled()
	
	if !Engine.editor_hint: return
	
	logger = Logger.get_for(self)
	
	_base_control = get_editor_interface().get_base_control()
	_resource_previewer = get_editor_interface().get_resource_previewer()
	
	# Using selection to start/stop editing of chosen Gardener
	get_editor_interface().get_selection().connect("selection_changed", self, "selection_changed")
	get_tree().connect("node_added", self, "on_tree_node_added")
	get_tree().connect("node_removed", self, "on_tree_node_removed")
	
	make_debug_view_menu()
	
	toolbar.add_child(VSeparator.new())
	toolbar.add_child(debug_view_menu)


func _enter_tree():
	# We need settings without editor too
	ProjectSettingsManager.add_plugin_project_settings()
	
	if !Engine.editor_hint: return
	
	adapt_editor_theme()
	
	side_panel_ND.theme = control_theme
	toolbar.visible = false
	
	add_custom_types()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, side_panel_ND)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, toolbar)
	selection_changed()


func _exit_tree():
	if !Engine.editor_hint: return
	
	set_gardener_edit_state(null)
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, side_panel_ND)
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, toolbar)
	remove_custom_types()


func apply_changes():
	if !Engine.editor_hint: return
	
	apply_changes_to_gardeners()


func add_custom_types():
	add_custom_type("Gardener", "Spatial", Gardener, gardener_icon)
	add_custom_type("Greenhouse", "Resource", Greenhouse, null)
	add_custom_type("Greenhouse_Plant", "Resource", Greenhouse_Plant, null)
	add_custom_type("Greenhouse_PlantState", "Resource", Greenhouse_PlantState, null)
	add_custom_type("Greenhouse_LODVariant", "Resource", Greenhouse_LODVariant, null)
	add_custom_type("Toolshed", "Resource", Toolshed, null)
	add_custom_type("Toolshed_Brush", "Resource", Toolshed_Brush, null)
	add_custom_type("PlacementTransform", "Resource", PlacementTransform, null)


func remove_custom_types():
	remove_custom_type("Gardener")
	remove_custom_type("Greenhouse")
	remove_custom_type("Greenhouse_Plant")
	remove_custom_type("Greenhouse_PlantState")
	remove_custom_type("Greenhouse_LODVariant")
	remove_custom_type("Toolshed")
	remove_custom_type("Toolshed_Brush")
	remove_custom_type("PlacementTransform")


func on_tree_node_added(node:Node):
	if FunLib.obj_is_script(node, Gardener):
		gardeners_in_tree.append(node)
	
	if node.has_method("set_undo_redo"):
		node.set_undo_redo(get_undo_redo())
	if node.has_method("set_editor_selection"):
		node.set_editor_selection(get_editor_interface().get_selection())


func on_tree_node_removed(node:Node):
	if FunLib.obj_is_script(node, Gardener):
		gardeners_in_tree.erase(node)


# Call apply_changes on all Gardeners in the scene
func apply_changes_to_gardeners():
	for gardener in gardeners_in_tree:
		if gardener is Gardener && is_instance_valid(gardener):
			gardener.apply_changes()




#-------------------------------------------------------------------------------
# Input
#-------------------------------------------------------------------------------


# Allows editor to forward us the spatial GUI input for any Gardener
func handles(object):
	return object is Gardener


# Handle events
# Propagate editor camera
# Forward input to Gardener if selected
func forward_spatial_gui_input(camera, event):
	propagate_camera(camera)
	
	var handled = false
	
	if is_instance_valid(active_gardener):
		handled = active_gardener.forwarded_input(camera, event)
	
	if !handled:
		plugin_input(event)
	
	return handled


func plugin_input(event):
	if event is InputEventKey && !event.pressed:
		if event.scancode == debug_get_dump_editor_tree_key():
			debug_dump_editor_tree()
		elif (event.scancode == get_focus_painter_key() 
			&& !Input.is_key_pressed(KEY_SHIFT) && !Input.is_key_pressed(KEY_CONTROL) && !Input.is_key_pressed(KEY_ALT) && !Input.is_key_pressed(KEY_SYSREQ)):
			focus_painter()


# A hack to propagate editor camera using forward_spatial_gui_input
func propagate_camera(camera:Camera):
	for gardener in gardeners_in_tree:
		if is_instance_valid(gardener):
			gardener.propagate_camera(camera)


func on_debug_view_menu_id_pressed(id):
	if is_instance_valid(active_gardener):
		active_gardener.debug_view_flag_checked(debug_view_menu, id)


# A somewhat hacky way to focus editor camera on the painter
func focus_painter():
	if !Engine.editor_hint: return
	if !active_gardener: return
	
	var editor_selection:EditorSelection = get_editor_interface().get_selection()
	if get_editor_interface().get_selection().is_connected("selection_changed", self, "selection_changed"):
		get_editor_interface().get_selection().disconnect("selection_changed", self, "selection_changed")
	
	editor_selection.clear()
	editor_selection.add_node(active_gardener.painter.paint_brush_node)
	
	simulate_key(KEY_F)
	# Have to delay that so input has time to process
	call_deferred("restore_gardener_selection")


func simulate_key(scancode):
	var event = InputEventKey.new()
	event.scancode = scancode
	event.pressed = true
	Input.parse_input_event(event)


# Restore selection to seamlessly continue gardener editing
func restore_gardener_selection():
	if !Engine.editor_hint: return
	if !active_gardener: return
	
	var editor_selection:EditorSelection = get_editor_interface().get_selection()
	editor_selection.clear()
	editor_selection.add_node(active_gardener)
	
	if !get_editor_interface().get_selection().is_connected("selection_changed", self, "selection_changed"):
		get_editor_interface().get_selection().connect("selection_changed", self, "selection_changed")


func get_focus_painter_key():
	var key = FunLib.get_setting_safe("dreadpon_spatial_gardener/input_and_ui/focus_painter_key", KEY_Q)
	return Globals.index_to_enum(key, Globals.KeyList)




#-------------------------------------------------------------------------------
# UI
#-------------------------------------------------------------------------------


func make_debug_view_menu():
	debug_view_menu = DebugViewer.make_debug_view_menu()
	debug_view_menu.get_popup().connect("id_pressed", self, "on_debug_view_menu_id_pressed")


# Modify editor theme to use proper colors, margins, etc.
func adapt_editor_theme():
	if !Engine.editor_hint: return
	
	var editorTheme = ThemeAdapter.get_theme(get_editor_interface().get_inspector())
	control_theme = Theme.new()
	control_theme.copy_theme(editorTheme)
	ThemeAdapter.adapt_theme(control_theme)




#-------------------------------------------------------------------------------
# Gardener editing lifecycle
#-------------------------------------------------------------------------------


# Selection changed. Check if we should start/stop editing a Gardener
func selection_changed():
	assert(get_editor_interface() && get_editor_interface().get_selection())
	
	var selection = get_editor_interface().get_selection().get_selected_nodes()
	handle_selected_gardener(selection)


func handle_selected_gardener(selection:Array):
	var gardener = null
	
	if selection.size() == 1:
		# Find a Gardener in selection. If found more than one - abort because of ambiguity
		for selected in selection:
			if selected is Gardener:
				if gardener:
					gardener = null
					logger.warn("Cannot edit multiple Gardeners at once!")
				if !gardener:
					gardener = selected
	
	if gardener:
		if gardener == active_gardener: return
		set_gardener_edit_state(selection[0])
	else:
		set_gardener_edit_state(null)


# Start/stop editing an active Gardener
func set_gardener_edit_state(gardener):
	if is_instance_valid(active_gardener) && active_gardener != gardener:
		active_gardener.stop_editing()
		active_gardener = null
	
	if !gardener:
		side_panel_ND.visible = false
		toolbar.visible = false
	
	if gardener:
		active_gardener = gardener
		active_gardener.start_editing(_base_control, _resource_previewer, get_undo_redo(), side_panel_ND)
		side_panel_ND.visible = true
		toolbar.visible = true
		active_gardener.up_to_date_debug_view_menu(debug_view_menu)




#-------------------------------------------------------------------------------
# Debug
#-------------------------------------------------------------------------------


# Dump the whole editor tree to console
func debug_dump_editor_tree():
	debug_dump_node_descendants(get_editor_interface().get_editor_viewport())


func debug_dump_node_descendants(node:Node, intendation:int = 0):
	var intend_str = ""
	for i in range(0, intendation):
		intend_str += "	"
	var string = "%s%s" % [intend_str, str(node)]
	logger.info(string)
	
	intendation += 1
	for child in node.get_children():
		debug_dump_node_descendants(child, intendation)


func debug_get_dump_editor_tree_key():
	var key = FunLib.get_setting_safe("dreadpon_spatial_gardener/debug/dump_editor_tree_key", 0)
	return Globals.index_to_enum(key, Globals.KeyList)


func debug_toggle_console():
	var current_scene := get_tree().get_current_scene()
	if current_scene.has_node("Console") && current_scene.get_node("Console") is Console:
		current_scene.remove_child(current_scene.get_node("Console"))
	else:
		var console = Console_SCN.instance()
		current_scene.add_child(console)
