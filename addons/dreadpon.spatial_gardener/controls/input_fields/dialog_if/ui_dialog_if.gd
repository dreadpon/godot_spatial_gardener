@tool
extends ConfirmationDialog


#-------------------------------------------------------------------------------
# A dialog that displays InputField controls
# Has confirmation and cancellation buttons
#-------------------------------------------------------------------------------




@onready var panel_container_fields_nd: Control = $VBoxContainer_Main/PanelContainer_Fields
@onready var fields = $VBoxContainer_Main/PanelContainer_Fields/VBoxContainer_Fields




func _init():
	set_meta("class", "UI_Dialog_IF")
	ok_button_text = "Apply"
	cancel_button_text = "Cancel"
	close_requested.connect(hide)
