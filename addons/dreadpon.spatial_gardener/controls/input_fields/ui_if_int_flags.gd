@tool
extends "ui_input_field.gd"


#-------------------------------------------------------------------------------
# Stores an int value
# Uses a bitfield selector akin to Godot's own
#-------------------------------------------------------------------------------

const EditorPropertyLayersGrid = preload("../extensions/ui_layers_grid.gd")
#const EditorInterfaceInterface = preload("../../utility/editor_interface_interface.gd")

enum LayerType {
	LAYER_PHYSICS_2D,
	LAYER_RENDER_2D,
	LAYER_NAVIGATION_2D,
	LAYER_PHYSICS_3D,
	LAYER_RENDER_3D,
	LAYER_NAVIGATION_3D,
	LAYER_AVOIDANCE,
}

var grid: EditorPropertyLayersGrid = null
var basename: String
var layer_type: LayerType
var layers: PopupMenu = null
var button: TextureButton = null




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val, __labelText:String = "NONE", __prop_name:String = "", settings:Dictionary = {}):
	super(__init_val, __labelText, __prop_name, settings)
	
	var hb = HBoxContainer.new()
	hb.set_clip_contents(true)
	container_box.add_child(hb)
	grid = EditorPropertyLayersGrid.new()
	grid.flag_changed.connect(_grid_changed)
	grid.rename_confirmed.connect(set_layer_name)
	grid.set_h_size_flags(SIZE_EXPAND_FILL)
	hb.add_child(grid)
	hb.set_h_size_flags(SIZE_EXPAND_FILL)

	button = TextureButton.new()
	button.set_stretch_mode(TextureButton.STRETCH_KEEP_CENTERED)
	button.set_toggle_mode(true)
	button.pressed.connect(_button_pressed)
	hb.add_child(button)

	# Idk what exactly it did in source, but just adding it as a child of container_box seems to work
	#set_bottom_editor(hb)

	layers = PopupMenu.new()
	container_box.add_child(layers)
	layers.set_hide_on_checkable_item_selection(false)
	layers.id_pressed.connect(_menu_pressed)
	layers.popup_hide.connect(button.set_pressed.bind(false))
	ProjectSettings.settings_changed.connect(_refresh_names)
	
	var _layer_type
	match settings.hint:
		PROPERTY_HINT_FLAGS:
			pass
		PROPERTY_HINT_LAYERS_2D_RENDER:
			_layer_type = LayerType.LAYER_RENDER_2D
		PROPERTY_HINT_LAYERS_2D_PHYSICS:
			_layer_type = LayerType.LAYER_PHYSICS_2D
		PROPERTY_HINT_LAYERS_2D_NAVIGATION:
			_layer_type = LayerType.LAYER_NAVIGATION_2D
		PROPERTY_HINT_LAYERS_3D_RENDER:
			_layer_type = LayerType.LAYER_RENDER_3D
		PROPERTY_HINT_LAYERS_3D_PHYSICS:
			_layer_type = LayerType.LAYER_PHYSICS_3D
		PROPERTY_HINT_LAYERS_3D_NAVIGATION:
			_layer_type = LayerType.LAYER_NAVIGATION_3D
		PROPERTY_HINT_LAYERS_AVOIDANCE:
			_layer_type = LayerType.LAYER_AVOIDANCE
	setup(_layer_type)


func _cleanup():
	super()
	if is_instance_valid(grid): grid.queue_free()
	if is_instance_valid(layers): layers.queue_free()
	if is_instance_valid(button): button.queue_free()
	grid = null
	layers = null
	button = null


func _notification(p_what: int) -> void:
	match p_what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_THEME_CHANGED:
			button.set_texture_normal(get_theme_icon("GuiTabMenuHl", "EditorIcons"))
			button.set_texture_pressed(get_theme_icon("GuiTabMenuHl", "EditorIcons"))
			button.set_texture_disabled(get_theme_icon("GuiTabMenu", "EditorIcons"))




func _set_read_only(p_read_only: bool) -> void: # override
	button.set_disabled(p_read_only)
	grid.set_read_only(p_read_only)


func setup(p_layer_type: LayerType) -> void:
	layer_type = p_layer_type
	var layer_group_size := 0
	var layer_count := 0
	match p_layer_type:
		LayerType.LAYER_RENDER_2D: 
			basename = "layer_names/2d_render"
			layer_group_size = 5
			layer_count = 20

		LayerType.LAYER_PHYSICS_2D: 
			basename = "layer_names/2d_physics"
			layer_group_size = 4
			layer_count = 32

		LayerType.LAYER_NAVIGATION_2D: 
			basename = "layer_names/2d_navigation"
			layer_group_size = 4
			layer_count = 32

		LayerType.LAYER_RENDER_3D: 
			basename = "layer_names/3d_render"
			layer_group_size = 5
			layer_count = 20

		LayerType.LAYER_PHYSICS_3D: 
			basename = "layer_names/3d_physics"
			layer_group_size = 4
			layer_count = 32

		LayerType.LAYER_NAVIGATION_3D: 
			basename = "layer_names/3d_navigation"
			layer_group_size = 4
			layer_count = 32

		LayerType.LAYER_AVOIDANCE: 
			basename = "layer_names/avoidance"
			layer_group_size = 4
			layer_count = 32
	

	var names: Array[String] = []
	var tooltips: Array[String] = []
	for i in range(layer_count):
		var name: String

		if ProjectSettings.has_setting(basename + "/layer_%d" % [i + 1]):
			name = ProjectSettings.get_setting_with_override(basename + "/layer_%d" % [i + 1])

		if name.is_empty():
			name = "Layer %d" % [i + 1]

		names.push_back(name)
		tooltips.push_back(name + "\n" + "Bit %d, value %d" % [i, 1 << i])
	

	grid.names = names
	grid.tooltips = tooltips
	grid.layer_group_size = layer_group_size
	grid.layer_count = layer_count




#-------------------------------------------------------------------------------
# Property management
#-------------------------------------------------------------------------------


func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
		_update_ui_to_val(final_val)


func _update_ui_to_val(val):
	grid.set_flag(val)
	super._update_ui_to_val(val)


func _string_to_val(string) -> int:
	if string is String:
		if string.is_valid_int():
			return string.to_int()
		else:
			logger.warn("String cannot be converted to int!")
	elif string is int:
		return string
	else:
		logger.warn("Passed variable is not a string or int!")
	return 0


func set_layer_name(p_index: int, p_name: String) -> void:
	var property_name := basename + "/layer_%d" % [p_index + 1]
	if ProjectSettings.has_setting(property_name):
		ProjectSettings.set(property_name, p_name)
		ProjectSettings.save()


func get_layer_name(p_index: int) -> String:
	var property_name := basename + "/layer_%d" % [p_index + 1]
	if ProjectSettings.has_setting(property_name):
		return ProjectSettings.get_setting_with_override(property_name);
	return ""




#-------------------------------------------------------------------------------
# Input
#-------------------------------------------------------------------------------



func _grid_changed(p_grid: int) -> void:
	_request_prop_action(p_grid, "PA_PropSet")


func _button_pressed() -> void:
	var layer_count := grid.layer_count
	layers.clear()
	for i in range(0, layer_count): 
		var name := get_layer_name(i)
		if name.is_empty():
			continue
		
		layers.add_check_item(name, i)
		var idx := layers.get_item_index(i)
		layers.set_item_checked(idx, grid.value & (1 << i))
	

	if layers.get_item_count() == 0:
		layers.add_item("No Named Layers")
		layers.set_item_disabled(0, true)
	
	layers.add_separator()
	# TODO: can't use this to open ProjectSettings, Godot doesn't expose this function to plugins
	#		removing for now
	#layers.add_icon_item(get_theme_icon("Edit", "EditorIcons"), "Edit Layer Names", grid.layer_count)
	layers.add_item("Plugins can't open Project Settings")
	layers.add_item("You'll have to do it manually :(")
	layers.set_item_disabled(layers.get_item_count() - 2, true)
	layers.set_item_disabled(layers.get_item_count() - 1, true)

	var button_xform := button.get_screen_transform()
	var gp := Rect2(button_xform.get_origin(), button_xform.get_scale() * get_size())
	layers.reset_size()
	var popup_pos := gp.position - Vector2(layers.get_contents_minimum_size().x, 0)
	layers.set_position(popup_pos)
	layers.popup()


func _menu_pressed(p_menu: int) -> void:
	if p_menu >= grid.layer_count:
		pass
		# Popup ProjectSettings layer editor
		# ProjectSettingsEditor.set_general_page(basename)
	else:
		if grid.value & (1 << p_menu):
			grid.value &= ~(1 << p_menu)
		else:
			grid.value |= (1 << p_menu)
		
		grid.queue_redraw()
		layers.set_item_checked(layers.get_item_index(p_menu), grid.value & (1 << p_menu))
		_grid_changed(grid.value)
	


func _refresh_names() -> void:
	setup(layer_type);
