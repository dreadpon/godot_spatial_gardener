@tool
extends "ui_input_field.gd"


#-------------------------------------------------------------------------------
# Displays some text
#-------------------------------------------------------------------------------

var displayed_label: Label = null




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val, __labelText:String = "NONE", __prop_name:String = "", settings:Dictionary = {}):
	super(__init_val, __labelText, __prop_name, settings)
	
	set_meta("class", "UI_IF_PlainText")
	
	displayed_label = Label.new()
	displayed_label.name = "displayed_label"
	displayed_label.size_flags_horizontal = SIZE_EXPAND_FILL
	displayed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if settings.has("label_visibility"):
		label.visible = settings.label_visibility
	
	container_box.add_child(displayed_label)


func _cleanup():
	super()
	if is_instance_valid(displayed_label):
		displayed_label.queue_free()



#-------------------------------------------------------------------------------
# Updaing the UI
#-------------------------------------------------------------------------------


func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
		_update_ui_to_val(final_val)


func _update_ui_to_val(val):
	displayed_label.text = val
	super._update_ui_to_val(val)
