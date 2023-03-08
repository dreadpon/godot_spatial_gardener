@tool
extends UI_InputField
class_name UI_IF_PlainText

#-------------------------------------------------------------------------------
# Displays some text
#-------------------------------------------------------------------------------

var displayed_label: Label = null




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val,__labelText:String = "NONE",__prop_name:String = "",settings:Dictionary = {}):
	
	set_meta("class", "UI_IF_PlainText")
	
	displayed_label = Label.new()
	displayed_label.name = "displayed_label"
	displayed_label.size_flags_horizontal = SIZE_EXPAND_FILL
	displayed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if settings.has("label_visibility"):
		label.visible = settings.label_visibility


func _ready():
	value_container.add_child(displayed_label)
	_init_ui()




#-------------------------------------------------------------------------------
# Updaing the UI
#-------------------------------------------------------------------------------


func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
		_update_ui_to_val(final_val)


func _update_ui_to_val(val):
	displayed_label.text = val
	super._update_ui_to_val(val)
