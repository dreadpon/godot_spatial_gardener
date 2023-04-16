@tool
extends Window


#-------------------------------------------------------------------------------
# A dialog that displays InputField controls
# Has confirmation and cancellation buttons
#-------------------------------------------------------------------------------


const ThemeAdapter = preload("../../theme_adapter.gd")

@onready var panel_container_fields_nd: Control = $VBoxContainer_Main/PanelContainer_Fields
@onready var fields = $VBoxContainer_Main/PanelContainer_Fields/VBoxContainer_Fields


signal confirmed
signal cancelled




func _init():
	set_meta("class", "UI_Dialog_IF")


func on_button_apply_pressed():
	confirmed.emit()


func on_button_cancel_pressed():
	cancelled.emit()


func _on_about_to_show():
	pass
