tool
extends PanelContainer


#-------------------------------------------------------------------------------
# A parent class for name-value pairs similar to built-in inspector properties
# Is bound to a given property of a given object
# Will update this property if changed
# And will change if this property is updated elsewhere
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


const tab_size:float = 5.0


# A container for all displayed controls
var container_box:HBoxContainer = HBoxContainer.new()
# Gives a visual offset whenever neccessary
# Also sets the background color
var tab_spacer:Control = Control.new()
# Stores the name of our property
var label:Label = Label.new()
# Stores the value of our property
var value_container:HBoxContainer = HBoxContainer.new()

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
#var visibility_tracked_properties:Array = []
#var visibility_is_tracked:bool = false setget set_visibility_is_tracked

var _undo_redo:UndoRedo = null
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
	
	value_container.name = "value_container"
	value_container.size_flags_horizontal = SIZE_EXPAND_FILL
	value_container.alignment = BoxContainer.ALIGN_CENTER
	
	if settings.has("tab"):
		tab_index = settings.tab
	
	set_stylebox(get_stylebox('panel', 'PanelContainer'))
	
	set_tooltip(tooltip)


func _ready():
	add_child(container_box)
	container_box.add_child(tab_spacer)
	container_box.add_child(label)
	container_box.add_child(value_container)
	_set_tab(tab_index)


# Set tabulation offset and color
func _set_tab(index:int):
	tab_index = index
	tab_spacer.rect_min_size.x = tab_index * tab_size
	tab_spacer.rect_size.x = tab_spacer.rect_min_size.x
	tab_spacer.visible = false if tab_index <= 0 else true
	
	if tab_index > 0:
		var styleboxes = ThemeAdapter.lookup_sub_inspector_styleboxes(self, tab_index - 1)
		set_stylebox(styleboxes.sub_inspector_bg)
	else:
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color.transparent
		set_stylebox(stylebox)


func set_tooltip(tooltip:String):
	if tooltip.length() > 0:
		label.mouse_filter = MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_HELP
		label.hint_tooltip = tooltip
	else:
		label.mouse_filter = MOUSE_FILTER_IGNORE


func set_stylebox(stylebox:StyleBox):
	stylebox = stylebox.duplicate()
	stylebox.content_margin_bottom = 1
	stylebox.content_margin_top = 1
	stylebox.content_margin_right = 0
	stylebox.content_margin_left = 0
	add_stylebox_override("panel", stylebox)




#-------------------------------------------------------------------------------
# Updaing the UI
#-------------------------------------------------------------------------------


# Property changed outside of this InputField
# Update the UI
func on_prop_action_executed(prop_action:PropAction, final_val):
	if prop_action.prop == prop_name:
		_update_ui_to_prop_action(prop_action, final_val)
#	on_tracked_property_changed(prop_action.prop, final_val)


func on_prop_list_changed(prop_dict: Dictionary):
	if visibility_forced >= 0:
		visible = true if visibility_forced == 1 else false
	else:
		visible =  prop_dict[prop_name].usage & PROPERTY_USAGE_EDITOR


# Actually respond to different PropActions
# To be overridden
func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	pass


# Set UI values for the first time
func _init_ui():
	_update_ui_to_val(init_val)
	init_val = null


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
	emit_signal("prop_action_requested", prop_action)




#-------------------------------------------------------------------------------
# Input
#-------------------------------------------------------------------------------


# Release focus from a child node when pressing enter
func on_node_received_input(event, node):
	if node.has_focus():
		if event is InputEventKey && !event.pressed:
			if event.scancode == KEY_ENTER || event.scancode == KEY_ESCAPE:
				node.release_focus()




#-------------------------------------------------------------------------------
# Tracking conditional visibility properties
#-------------------------------------------------------------------------------

# visibility_tracked_properties[] is an array of dictionaries that track properties belonging to certain objects
# If all of them have the target value - show this Control. Otherwise - hide it

# Add a new property to track
#func add_tracked_property(prop:String, target_val, initial_val = null):
#	visibility_tracked_properties.append({
#		"prop": prop,
#		"target_val": target_val,
#		"last_val": initial_val,
#	})
#
#
## Reset all properties from being tracked
#func reset_visibility_tracked_properties(val):
#	visibility_tracked_properties = []
#
#
## A property has changed. Check if it is being tracked and update its value
#func on_tracked_property_changed(prop:String, val):
#	var prop_dict = null
#	for prop_dict_search in visibility_tracked_properties:
#		if prop_dict_search.prop == prop:
#			prop_dict = prop_dict_search
#
#	if prop_dict:
#		prop_dict.last_val = val
#
#	_try_visibility_check()
#
#
## Enable/disable conditional visibility tracking
#func set_visibility_is_tracked(val):
#	visibility_is_tracked = val
#	_try_visibility_check()
#
#
## Test if all tracked properties are of the needed value
#func _try_visibility_check():
#	if !visibility_is_tracked: return
#
#	if visibility_forced == 0:
#		visible = false
#		return
#	elif visibility_forced > 0:
#		visible = true
#		return
#
#	var result := true
#	for prop_dict in visibility_tracked_properties:
#		if prop_dict.last_val != prop_dict.target_val:
#			result = false
#			break
#
#	visible = result




#-------------------------------------------------------------------------------
# Debug
#-------------------------------------------------------------------------------


func debug_print_prop_action(string:String):
	if !FunLib.get_setting_safe("dreadpons_spatial_gardener/debug/input_field_resource_log_prop_actions", false): return
	logger.info(string)
