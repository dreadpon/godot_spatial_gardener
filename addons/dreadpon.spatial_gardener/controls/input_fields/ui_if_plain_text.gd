tool
extends "ui_input_field.gd"


#-------------------------------------------------------------------------------
# Displays some text
#-------------------------------------------------------------------------------

var displayed_label: Label = null




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val, __labelText:String = "NONE", __prop_name:String = "", settings:Dictionary = {}).(__init_val, __labelText, __prop_name, settings):
	
	set_meta("class", "UI_IF_PlainText")
	
	displayed_label = Label.new()
	displayed_label.name = "displayed_label"
	displayed_label.size_flags_horizontal = SIZE_EXPAND_FILL
	displayed_label.align = Label.ALIGN_CENTER
	
	if settings.has("label_visibility"):
		label.visible = settings.label_visibility


func _ready():
	value_container.add_child(displayed_label)
	_init_ui()




#-------------------------------------------------------------------------------
# Updaing the UI
#-------------------------------------------------------------------------------


func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	if prop_action is PA_PropSet || prop_action is PA_PropEdit:
		_update_ui_to_val(final_val)


func _update_ui_to_val(val):
	displayed_label.text = val
	._update_ui_to_val(val)
