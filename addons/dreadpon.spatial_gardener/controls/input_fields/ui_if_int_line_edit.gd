@tool
extends UI_InputField
class_name UI_IF_IntLineEdit

#-------------------------------------------------------------------------------
# Stores an int value
# Has a slider + line_edit for convinience
#-------------------------------------------------------------------------------


var value_input:LineEdit = null




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val,__labelText:String = "NONE",__prop_name:String = "",settings:Dictionary = {}):
	set_meta("class", "UI_IF_IntLineEdit")
	
	value_input = LineEdit.new()
	value_input.name = "value_input"
	value_input.size_flags_horizontal = SIZE_EXPAND_FILL
	value_input.size_flags_stretch_ratio = 0.5
	value_input.custom_minimum_size.x = 25.0
	value_input.size_flags_vertical = SIZE_SHRINK_CENTER
	value_input.connect("focus_entered",Callable(self,"select_line_edit").bind(value_input, true))
	value_input.connect("focus_exited",Callable(self,"select_line_edit").bind(value_input, false))
	# focus_exited is our main signal to commit the value in LineEdit
	# release_focus() is expected to be called when pressing enter and only then we commit the value
	value_input.connect("focus_exited",Callable(self,"focus_lost").bind(value_input))
	value_input.connect("gui_input",Callable(self,"on_node_received_input").bind(value_input))
	ThemeAdapter.assign_node_type(value_input, 'IF_LineEdit')


func _ready():
	value_container.add_child(value_input)
	_init_ui()




#-------------------------------------------------------------------------------
# Property management
#-------------------------------------------------------------------------------


func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
		_update_ui_to_val(final_val)


func _update_ui_to_val(val):
	val = _string_to_val(val)
	value_input.text = String(val)
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
		logger.warn("Passed variable is not a string!")
	return 0


func _convert_and_request(val, prop_action_class:String):
	_request_prop_action(_string_to_val(val), prop_action_class)




#-------------------------------------------------------------------------------
# Input
#-------------------------------------------------------------------------------


func focus_lost(line_edit:LineEdit):
	_convert_and_request(line_edit.text, "PA_PropSet")


# Auto select all text when user clicks inside
func select_line_edit(line_edit:LineEdit, state:bool):
	if state:
		line_edit.call_deferred("select_all")
	else:
		line_edit.call_deferred("deselect")
