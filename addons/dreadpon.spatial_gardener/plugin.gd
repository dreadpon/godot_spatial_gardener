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
const UI_SidePanel_SCN = preload("controls/side_panel/ui_side_panel.tscn")
const UI_SidePanel = preload("controls/side_panel/ui_side_panel.gd")
const ThemeAdapter = preload("controls/theme_adapter.gd")
const SceneConverter = preload("scene_converter/scene_converter.gd")

const Greenhouse = preload("greenhouse/greenhouse.gd")
const Greenhouse_Plant = preload("greenhouse/greenhouse_plant.gd")
const Greenhouse_PlantState = preload("greenhouse/greenhouse_plant_state.gd")
const Greenhouse_LODVariant = preload("greenhouse/greenhouse_LOD_variant.gd")
const Toolshed = preload("toolshed/toolshed.gd")
const Toolshed_Brush = preload("toolshed/toolshed_brush.gd")

const Console_SCN = preload("utility/console/console.tscn")
const Console = preload("utility/console/console.gd")

const gardener_icon:Texture = preload("icons/gardener_icon.svg")


var _side_panel:UI_SidePanel = null
var _base_control:Control = Control.new()
var _resource_previewer = null
var control_theme:Theme = null

var toolbar:HBoxContainer = HBoxContainer.new()
var debug_view_menu:MenuButton

var active_gardener = null
var gardeners_in_tree:Array = []
var folding_states: Dictionary = {}
var scene_converter: SceneConverter = null

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
	
	_base_control = get_editor_interface().get_base_control()
	_resource_previewer = get_editor_interface().get_resource_previewer()
	
	adapt_editor_theme()
	ProjectSettings.connect('project_settings_changed', self, '_on_project_settings_changed')
	
	scene_converter = SceneConverter.new()
	scene_converter.setup(_base_control)
	_side_panel = UI_SidePanel_SCN.instance()
	_side_panel.theme = control_theme
	toolbar.visible = false
	
	add_custom_types()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, _side_panel)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, toolbar)
	selection_changed()
	


func _exit_tree():
	if !Engine.editor_hint: return
		
	if scene_converter:
		scene_converter.destroy()
	
	set_gardener_edit_state(null)
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, _side_panel)
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, toolbar)
	remove_custom_types()



# Previously here was 'apply_changes', but it fired even when scene was closed without saving
# 'save_external_data' respects saving/not saving choice
func save_external_data():
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


func remove_custom_types():
	remove_custom_type("Gardener")
	remove_custom_type("Greenhouse")
	remove_custom_type("Greenhouse_Plant")
	remove_custom_type("Greenhouse_PlantState")
	remove_custom_type("Greenhouse_LODVariant")
	remove_custom_type("Toolshed")
	remove_custom_type("Toolshed_Brush")


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


func get_plugin_name() -> String:
	return 'SpatialGardener'


func _on_project_settings_changed():
	if scene_converter:
		scene_converter._on_project_settings_changed()




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
	var key = FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/focus_painter_key", KEY_Q)
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


# Gather folding states from side panel
func get_state() -> Dictionary:
	_side_panel.cleanup_folding_states(folding_states)
	return {'folding_states': folding_states}


# Restore folding states for side panel
func set_state(state: Dictionary):
	folding_states = state.folding_states


func on_greenhouse_prop_action_executed(prop_action, final_val):
	_side_panel.on_greenhouse_prop_action_executed(folding_states, active_gardener.greenhouse, prop_action, final_val)


func refresh_folding_state_for_greenhouse(greenhouse):
	if greenhouse:
		_side_panel.refresh_folding_states_for_greenhouse(folding_states, greenhouse)




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
	if (is_instance_valid(active_gardener) && active_gardener != gardener) || !gardener:
		stop_gardener_edit()
	
	if gardener:
		start_gardener_edit(gardener)


func start_gardener_edit(gardener):
	active_gardener = gardener
	# TODO: figure out this weird bug :/
	#		basically, when having 2 scenes open, one with gardener and another NOT SAVED PREVIOUSLY (new empty scene)
	#		if you switch to an empty scene and save it, gardener loses all references (this doesnt happen is was saved at least once)
	#		To prevent that we call _ready each time we start gardener editing
	#		But this leads to some nodes being instanced again, even though they already exist 
	#		This is a workaround that I haven't tested extensively, so it might backfire in the future
	#
	#		There's more.
	#		Foldable states are reset two (maybe even all resource incuding gardeners and toolsheds, etc.?)
	#			Doesn't seem so, but still weird
	#
	#		Worth noting, that this leads to a severe slowdown when clicking through gardeners in a scene
	#		Since stuff like "restoring after load" has to run again
#	active_gardener._ready()
	
	# I am testing a workaround of just restoring references, to avoid the unneccesary operations caused be previous solution
	# UPD: Actually seems to work even without calling the method below. I'm confused
	# I'll keep it here *just in case* the bug still persists but hides well
	active_gardener.restore_references()
	
	active_gardener.connect("tree_exited", self, "set_gardener_edit_state", [null])
	active_gardener.connect("greenhouse_prop_action_executed", self, "on_greenhouse_prop_action_executed")
	active_gardener.start_editing(_base_control, _resource_previewer, get_undo_redo(), _side_panel)
	_side_panel.visible = true
	toolbar.visible = true
	active_gardener.up_to_date_debug_view_menu(debug_view_menu)
	refresh_folding_state_for_greenhouse(active_gardener.greenhouse)


func stop_gardener_edit():
	get_state()

	_side_panel.visible = false
	toolbar.visible = false

	if active_gardener:
		active_gardener.stop_editing()
		if active_gardener.is_connected("tree_exited", self, "set_gardener_edit_state"):
			active_gardener.disconnect("tree_exited", self, "set_gardener_edit_state")
		if active_gardener.is_connected("greenhouse_prop_action_executed", self, "on_greenhouse_prop_action_executed"):
			active_gardener.disconnect("greenhouse_prop_action_executed", self, "on_greenhouse_prop_action_executed")
		
	active_gardener = null




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
	var key = FunLib.get_setting_safe("dreadpons_spatial_gardener/debug/dump_editor_tree_key", 0)
	return Globals.index_to_enum(key, Globals.KeyList)


func debug_toggle_console():
	var current_scene := get_tree().get_current_scene()
	if current_scene.has_node("Console") && current_scene.get_node("Console") is Console:
		current_scene.remove_child(current_scene.get_node("Console"))
	else:
		var console = Console_SCN.instance()
		current_scene.add_child(console)
