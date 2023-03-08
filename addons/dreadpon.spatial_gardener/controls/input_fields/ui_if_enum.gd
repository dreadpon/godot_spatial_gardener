@tool
extends UI_InputField
class_name UI_IF_Enum

#-------------------------------------------------------------------------------
# Stores an enum value
# Uses an OptionButton as a selection dropdown
#-------------------------------------------------------------------------------


var enum_selector:OptionButton = null




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val,__labelText:String = "NONE",__prop_name:String = "",settings:Dictionary = {}):
	set_meta("class", "UI_IF_Enum")
	
	enum_selector = OptionButton.new()
	enum_selector.name = "enum_selector"
	enum_selector.size_flags_horizontal = SIZE_EXPAND_FILL
	enum_selector.size_flags_vertical = SIZE_SHRINK_CENTER
	for i in range(0, settings.enum_list.size()):
		enum_selector.add_item(settings.enum_list[i], i)
	
	enum_selector.connect("item_selected",Callable(self,"_request_prop_action").bind("PA_PropSet"))
	ThemeAdapter.assign_node_type(enum_selector, 'InspectorButton')


func _ready():
	value_container.add_child(enum_selector)
	_init_ui()




#-------------------------------------------------------------------------------
# Updaing the UI
#-------------------------------------------------------------------------------


func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
		_update_ui_to_val(final_val)


func _update_ui_to_val(val):
	enum_selector.selected = val
	super._update_ui_to_val(val)
