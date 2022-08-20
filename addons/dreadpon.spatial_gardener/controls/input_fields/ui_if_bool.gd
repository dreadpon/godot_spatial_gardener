tool
extends "ui_input_field.gd"


#-------------------------------------------------------------------------------
# Stores a bool value
#-------------------------------------------------------------------------------


var bool_check:CheckBox = null




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val, __labelText:String = "NONE", __prop_name:String = "", settings:Dictionary = {}).(__init_val, __labelText, __prop_name, settings):
	set_meta("class", "UI_IF_Bool")
	
	bool_check = CheckBox.new()
	bool_check.name = "bool_check"
	bool_check.text = "On"
	bool_check.size_flags_horizontal = SIZE_EXPAND_FILL
	bool_check.size_flags_vertical = SIZE_SHRINK_CENTER
	bool_check.connect("toggled", self, "_request_prop_action", ["PA_PropSet"])
	ThemeAdapter.assign_node_type(bool_check, 'InspectorButton')


func _ready():
	value_container.add_child(bool_check)
	_init_ui()




#-------------------------------------------------------------------------------
# Updaing the UI
#-------------------------------------------------------------------------------


func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	if prop_action is PA_PropSet || prop_action is PA_PropEdit:
		_update_ui_to_val(final_val)


func _update_ui_to_val(val):
	bool_check.pressed = val
	._update_ui_to_val(val)
