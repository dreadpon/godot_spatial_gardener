@tool
extends UI_InputField
class_name UI_IF_Bool

#-------------------------------------------------------------------------------
# Stores a bool value
#-------------------------------------------------------------------------------


var bool_check:CheckBox = null




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val,__labelText:String = "NONE",__prop_name:String = "",settings:Dictionary = {}):
	set_meta("class", "UI_IF_Bool")
	
	bool_check = CheckBox.new()
	bool_check.name = "bool_check"
	bool_check.text = "On"
	bool_check.size_flags_horizontal = SIZE_EXPAND_FILL
	bool_check.size_flags_vertical = SIZE_SHRINK_CENTER
	bool_check.connect("toggled",Callable(self,"_request_prop_action").bind("PA_PropSet"))
	ThemeAdapter.assign_node_type(bool_check, 'InspectorButton')


func _ready():
	value_container.add_child(bool_check)
	_init_ui()




#-------------------------------------------------------------------------------
# Updaing the UI
#-------------------------------------------------------------------------------


func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
		_update_ui_to_val(final_val)


func _update_ui_to_val(val):
	bool_check.button_pressed = val
	super._update_ui_to_val(val)
