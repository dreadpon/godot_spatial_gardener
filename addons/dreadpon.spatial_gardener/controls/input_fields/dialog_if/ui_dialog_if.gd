tool
extends WindowDialog


#-------------------------------------------------------------------------------
# A dialog that displays InputField controls
# Has confirmation and cancellation buttons
#-------------------------------------------------------------------------------


onready var fields = get_node("VBoxContainer_main/MarginContainer_fields/VBoxContainer_fields")


signal confirmed
signal cancelled




func _init():
	set_meta("class", "UI_Dialog_IF")


func on_button_apply_pressed():
	emit_signal("confirmed")


func on_button_cancel_pressed():
	emit_signal("cancelled")
