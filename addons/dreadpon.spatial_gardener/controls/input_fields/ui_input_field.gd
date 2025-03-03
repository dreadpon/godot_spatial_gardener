@tool
extends PanelContainer


#-------------------------------------------------------------------------------
# A parent class for name-value pairs similar to built-in inspector properties
# Is bound to a given property of a given object
# Will update this property if changed
# And will change if this property is updated elsewhere
#
# TODO: convert to premade scenes?
#		this might speed up creation and setup of these elements
#-------------------------------------------------------------------------------


const ThemeAdapter = preload("../theme_adapter.gd")
const FunLib = preload("../../utility/fun_lib.gd")
const Logger = preload("../../utility/logger.gd")
const PropAction = preload("../../utility/input_field_resource/prop_action.gd")
const PA_PropSet = preload("../../utility/input_field_resource/pa_prop_set.gd")
const PA_PropEdit = preload("../../utility/input_field_resource/pa_prop_edit.gd")
const PA_ArrayInsert = preload("../../utility/input_field_resource/pa_array_insert.gd")
const PA_ArrayRemove = preload("../../utility/input_field_resource/pa_array_remove.gd")
const PA_ArraySet = preload("../../utility/input_field_resource/pa_array_set.gd")
const UndoRedoInterface = preload("../../utility/undo_redo_interface.gd")


const tab_size:float = 5.0


# A container for all displayed controls
var container_box:HBoxContainer = HBoxContainer.new()
# Gives a visual offset whenever neccessary
# Also sets the background color
var tab_spacer:Control = Control.new()
# Stores the name of our property
var label:Label = Label.new()

# Bound prop name
var prop_name:String = ""
# Value used to initialize UI for the first time
var init_val = null
# Cache the latest set value
# Can be reverted to from script
var val_cache = null

# A visual offset index
var tab_index:int = 0

# An override for input field's visibility
	# -1 - don't force any visibility state
	# 0/1 force invisible/visible state
var visibility_forced:int = -1

var _undo_redo = null
var disable_history:bool = false

var logger = null


signal prop_action_requested(prop_action)




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val, __labelText:String = "NONE", __prop_name:String = "", settings:Dictionary = {}, tooltip:String = ""):
	set_meta("class", "UI_InputField")
	
	logger = Logger.get_for(self)
	init_val = __init_val
	prop_name = __prop_name
	
	size_flags_horizontal = SIZE_EXPAND_FILL
	container_box.size_flags_horizontal = SIZE_EXPAND_FILL
	
	label.name = "label"
	label.text = __labelText
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	
	if settings.has("tab"):
		tab_index = settings.tab
	
	set_stylebox(get_theme_stylebox('panel', 'PanelContainer'))
	
	set_tooltip(tooltip)
	
	add_child(container_box)
	container_box.add_child(tab_spacer)
	container_box.add_child(label)


func _notification(what):
	match what:
		NOTIFICATION_PREDELETE:
			# Make sure we don't have memory leaks of keeping removed nodes in memory
			_cleanup()


# Clean up to avoid memory leaks of keeping removed nodes in memory
func _cleanup():
	if is_instance_valid(container_box):
		container_box.queue_free()
	if is_instance_valid(tab_spacer):
		tab_spacer.queue_free()
	if is_instance_valid(label):
		label.queue_free()


func prepare_input_field(__init_val, __base_control:Control, __resource_previewer):
	init_val = __init_val


func _ready():
	_set_tab(tab_index)


func _enter_tree():
	_update_ui_to_val(init_val)
	init_val = null


# Set tabulation offset and color
func _set_tab(index:int):
	tab_index = index
	tab_spacer.custom_minimum_size.x = tab_index * tab_size
	tab_spacer.size.x = tab_spacer.custom_minimum_size.x
	tab_spacer.visible = false if tab_index <= 0 else true
	
	if tab_index > 0:
		var styleboxes = ThemeAdapter.lookup_sub_inspector_styleboxes(self, tab_index)
		set_stylebox(styleboxes.sub_inspector_bg)
	else:
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color.TRANSPARENT
		set_stylebox(stylebox)


func set_tooltip(tooltip:String):
	if tooltip.length() > 0:
		label.mouse_filter = MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_HELP
		label.tooltip_text = tooltip
	else:
		label.mouse_filter = MOUSE_FILTER_IGNORE


func set_stylebox(stylebox:StyleBox):
	stylebox = stylebox.duplicate()
	stylebox.content_margin_bottom = 1
	stylebox.content_margin_top = 1
	stylebox.content_margin_right = 0
	stylebox.content_margin_left = 0
	add_theme_stylebox_override("panel", stylebox)




#-------------------------------------------------------------------------------
# Updaing the UI
#-------------------------------------------------------------------------------


# Property changed outside of this InputField
# Update the UI
func on_prop_action_executed(prop_action:PropAction, final_val):
	if prop_action.prop == prop_name:
		_update_ui_to_prop_action(prop_action, final_val)


func on_prop_list_changed(prop_dict: Dictionary):
	if visibility_forced >= 0:
		visible = true if visibility_forced == 1 else false
	else:
		visible = prop_dict[prop_name].usage & PROPERTY_USAGE_EDITOR


# Actually respond to different PropActions
# To be overridden
func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	pass


# Specific implementation of updating UI
# To be overridden
func _update_ui_to_val(val):
	val_cache = val


# Property changed by this InputField
# Request a PropAction
func _request_prop_action(val, prop_action_class:String, optional:Dictionary = {}):
	var prop_action:PropAction = null
	
	match prop_action_class:
		"PA_PropSet":
			prop_action = PA_PropSet.new(prop_name, val)
		"PA_PropEdit":
			prop_action = PA_PropEdit.new(prop_name, val)
		"PA_ArrayInsert":
			prop_action = PA_ArrayInsert.new(prop_name, val, optional.index)
		"PA_ArrayRemove":
			prop_action = PA_ArrayRemove.new(prop_name, val, optional.index)
		"PA_ArraySet":
			prop_action = PA_ArraySet.new(prop_name, val, optional.index)
	
	if disable_history:
		prop_action.can_create_history = false
	
	debug_print_prop_action("Requesting prop action: %s from \"%s\"" % [str(prop_action), name])
	prop_action_requested.emit(prop_action)




#-------------------------------------------------------------------------------
# Input
#-------------------------------------------------------------------------------


# Release focus from a child node when pressing enter
func on_node_received_input(event, node):
	if node.has_focus():
		if is_instance_of(event, InputEventKey) && !event.pressed:
			if event.keycode == KEY_ENTER || event.keycode == KEY_KP_ENTER || event.keycode == KEY_ESCAPE:
				node.release_focus()




#-------------------------------------------------------------------------------
# Debug
#-------------------------------------------------------------------------------


func debug_print_prop_action(string:String):
	if !FunLib.get_setting_safe("dreadpons_spatial_gardener/debug/input_field_resource_log_prop_actions", false): return
	logger.info(string)
