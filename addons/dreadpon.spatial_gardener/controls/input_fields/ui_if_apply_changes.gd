tool
extends "ui_input_field.gd"


#-------------------------------------------------------------------------------
# Shows a dialog with InputField controls when button is pressed
# InputField controls will be set with PA_PropSet if dialog was confirmed
# InputField controls will be reverted to initial values if dialog was cancelled
#-------------------------------------------------------------------------------


const UI_Dialog_IF = preload("dialog_if/ui_dialog_if.tscn")


var button:Button = null
var _base_control:Control = null
var apply_dialog:WindowDialog = null
var bound_input_fields:Array = []
var initial_values:Array = []
var final_values:Array = []


signal applied_changes(initial_values, final_values)
signal cancelled_changes




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val, __labelText:String = "NONE", __prop_name:String = "", settings:Dictionary = {}).(__init_val, __labelText, __prop_name, settings):
	
	set_meta("class", "UI_IF_ApplyChanges")
	
	button = Button.new()
	button.name = "button"
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.size_flags_vertical = SIZE_SHRINK_CENTER
	button.text = settings.button_text
	button.connect("pressed", self, "on_button_pressed")
	
	_base_control = settings._base_control
	
	apply_dialog = UI_Dialog_IF.instance()
	apply_dialog.window_title = settings.button_text
	apply_dialog.connect("confirmed", self, "on_dialog_confirmed")
	apply_dialog.connect("cancelled", self, "on_dialog_cancelled")
	apply_dialog.connect("popup_hide", self, "on_dialog_hidden")
	
	bound_input_fields = settings.bound_input_fields
	
	ThemeAdapter.assign_node_type(button, 'InspectorButton')


func _ready():
	value_container.add_child(button)
	_base_control.add_child(apply_dialog)
	for input_field in bound_input_fields:
		input_field.disable_history = true
		apply_dialog.fields.add_child(input_field)
	
	_init_ui()


func _exit_tree():
	if _base_control && _base_control.get_children().has(apply_dialog):
		_base_control.remove_child(apply_dialog)


func reset_dialog():
	initial_values = []
	final_values = []
	if apply_dialog.visible:
		apply_dialog.visible = false




#-------------------------------------------------------------------------------
# Button presses
#-------------------------------------------------------------------------------


func on_button_pressed():
	initial_values = gather_values()
	apply_dialog.popup_centered(Vector2(400, 200))# popup_centered_ratio(0.5)


func on_dialog_confirmed():
	final_values = gather_values()
	emit_signal("applied_changes", initial_values.duplicate(), final_values.duplicate())
	reset_dialog()


func on_dialog_cancelled():
	set_values(initial_values)
	emit_signal("cancelled_changes")
	reset_dialog()


func on_dialog_hidden():
	on_dialog_cancelled()




#-------------------------------------------------------------------------------
# Value management
#-------------------------------------------------------------------------------


func gather_values() -> Array:
	var values := []
	for input_field in bound_input_fields:
		values.append(input_field.val_cache)
	return values


func set_values(values):
	for i in range(0, values.size()):
		
		var input_field = bound_input_fields[i]
		var val = values[i]
		if val is Array || val is Dictionary:
			val = val.duplicate()
		
		var prop_action:PropAction = PA_PropSet.new(input_field.prop_name, val)
		prop_action.can_create_history = false
		
		debug_print_prop_action("Requesting prop action: %s from \"%s\"" % [str(prop_action), name])
		emit_signal("prop_action_requested", prop_action)
