@tool
extends "ui_input_field.gd"


#-------------------------------------------------------------------------------
# Stores an integer (int) value
# Has a slider + line_edit for convinience
#-------------------------------------------------------------------------------


var int_slider:HSlider = null
var value_input:SpinBox = null




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val, __labelText:String = "NONE", __prop_name:String = "", settings:Dictionary = {}):
	super(__init_val, __labelText, __prop_name, settings)
	set_meta("class", "UI_IF_IntSlider")
	
	int_slider = HSlider.new()
	int_slider.name = "int_slider"
	int_slider.size_flags_horizontal = SIZE_EXPAND_FILL
	int_slider.min_value = settings.min
	int_slider.max_value = settings.max
	int_slider.step = settings.step
	int_slider.allow_greater = settings.allow_greater
	int_slider.allow_lesser = settings.allow_lesser
	int_slider.size_flags_vertical = SIZE_SHRINK_CENTER
	int_slider.value_changed.connect(_convert_and_request.bind("PA_PropEdit"))
	int_slider.drag_ended.connect(_slider_drag_ended.bind("PA_PropSet"))
	
	value_input = SpinBox.new()
	value_input.name = "value_input"
	value_input.size_flags_horizontal = SIZE_EXPAND_FILL
	value_input.custom_minimum_size.x = 25.0
	value_input.size_flags_vertical = SIZE_SHRINK_CENTER
	# focus_exited is our main signal to commit the value in LineEdit
	# release_focus() is expected to be called when pressing enter and only then we commit the value
	value_input.focus_exited.connect(focus_lost.bind(value_input))
	value_input.value_changed.connect(_convert_and_request.bind("PA_PropEdit"))
	value_input.gui_input.connect(on_node_received_input.bind(value_input))
	value_input.theme_type_variation = "IF_LineEdit"
	value_input.select_all_on_focus = true
	value_input.min_value = settings.min
	value_input.max_value = settings.max
	value_input.step = settings.step
	value_input.allow_greater = settings.allow_greater
	value_input.allow_lesser = settings.allow_lesser
	
	int_slider.size_flags_stretch_ratio = 0.67
	value_input.size_flags_stretch_ratio = 0.33
	container_box.add_child(int_slider)
	container_box.add_child(value_input)


func _cleanup():
	super()
	if is_instance_valid(int_slider):
		int_slider.queue_free()
	if is_instance_valid(value_input):
		value_input.queue_free()




#-------------------------------------------------------------------------------
# Property management
#-------------------------------------------------------------------------------


func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
		_update_ui_to_val(final_val)


func _update_ui_to_val(val):
	# So uhm... the signal is emitted when setting value through a variable too
	# And I only want to emit it on UI interaction, so disconnect and then reconnect the signal
	int_slider.value_changed.disconnect(_convert_and_request)
	int_slider.value = val
	int_slider.value_changed.connect(_convert_and_request.bind("PA_PropEdit"))
	
	value_input.value = val
	
	super._update_ui_to_val(val)


func _slider_drag_ended(value_changed: bool, prop_action_class:String):
	_convert_and_request(int_slider.value, prop_action_class)


func _convert_and_request(val, prop_action_class:String):
	_request_prop_action(val, prop_action_class)




#-------------------------------------------------------------------------------
# Input
#-------------------------------------------------------------------------------


func focus_lost(line_edit:LineEdit):
	_convert_and_request(line_edit.value, "PA_PropSet")
