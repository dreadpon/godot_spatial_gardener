@tool
extends "ui_input_field.gd"


#-------------------------------------------------------------------------------
# Stores a struct with multiple real (float) values
# Possibly represents a min-max range
#-------------------------------------------------------------------------------


# Describes what data input_field receives and returns
# Does not affect how this data is stored internally (always in an array)
enum RepresentationType {
	VECTOR, # will input/output_array float/float[2], Vector2/Vector2[2], Vector3/Vector3[2], float[4]/float[4][2]
	VALUE, # will input/output_array float/float[2], float[2]/float[2][2], float[3]/float[3][2], float[4]/float[4][2]
	COLOR # will input/output_array float/float[2], float[2]/float[2][2], Color/Color[2], Color/Color[2]
	# COLOR CURRENTLY DOESN'T DO ANYTHING
	# AND SHOULD NOT BE USED
	# TODO add color support if it needed
}

const prop_label_text_colors:Array = ["97695c", "568268", "6b76b0", "a3a3a3"]
const prop_label_text:Dictionary = {
	RepresentationType.VECTOR: ["x", "y", "z", "w"],
	RepresentationType.VALUE: ["a", "b", "c", "d"],
	RepresentationType.COLOR: ["r", "g", "b", "a"]
}

var representation_type:int = RepresentationType.VECTOR
var value_count:int = 3

var is_range:bool = false
var field_container:GridContainer = null
var field_editable_controls:Array = []

# Internal (actual) value format:
	# [range_index][value_index]
# i.e: range of Vector3:
	# [[x1, y1, z1], [x2, y2, z2]]
# Rule of thumb:
	# FIRST comes range_index
	# SECOND comes value_index



#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val, __labelText:String = "NONE", __prop_name:String = "", settings:Dictionary = {}):
	super(__init_val, __labelText, __prop_name, settings)
	set_meta("class", "UI_IF_RealSlider")
	
	is_range = settings.is_range
	value_count = settings.value_count
	representation_type = settings.representation_type
	
	field_container = GridContainer.new()
	field_container.name = "field_container"
	field_container.add_theme_constant_override("h_separation", 0)
	field_container.add_theme_constant_override("v_separation", 2)
	field_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_container.columns = 4 if is_range else 2
	
	for range_index in range(0, 2 if is_range else 1):
		field_editable_controls.append([])
	
	for value_index in range(0, value_count):		
		var prop_label := Label.new()
		prop_label.name = "prop_label_-_%s" % [str(value_index)]
		prop_label.text = prop_label_text[representation_type][value_index]
		prop_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		prop_label.size_flags_vertical = Control.SIZE_FILL
		prop_label.custom_minimum_size = Vector2i(20, 0)
		
		field_container.add_child(prop_label)
		
		prop_label.theme_type_variation = "MultiRangePropLabel"
		prop_label.add_theme_color_override("font_color", Color(prop_label_text_colors[value_index]))
		
		for range_index in range(0, 2 if is_range else 1):
			var value_input = LineEdit.new()
			value_input.name = "value_input_%s_%s" % [str(range_index), str(value_index)]
			value_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			value_input.size_flags_vertical = Control.SIZE_FILL
			
			value_input.focus_entered.connect(select_line_edit.bind(value_input, true))
			value_input.focus_exited.connect(select_line_edit.bind(value_input, false))
			value_input.focus_exited.connect(focus_lost.bind(value_input, range_index, value_index))
			value_input.gui_input.connect(on_node_received_input.bind(value_input))
			
			field_editable_controls[range_index].append(value_input)
			field_container.add_child(value_input)
			value_input.theme_type_variation = "MultiRangeValue"
			
			if is_range && range_index == 0:
				var dash_label := Label.new()
				dash_label.name = "dash_label_-_%s" % [str(value_index)]
				dash_label.text = "–"
				dash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				dash_label.size_flags_vertical = Control.SIZE_FILL
				dash_label.custom_minimum_size = Vector2i(20, 0)
				
				field_container.add_child(dash_label)
				
				dash_label.theme_type_variation = "MultiRangeDashLabel"
				dash_label.add_theme_color_override("font_color", Color(prop_label_text_colors[value_index]))
	
	container_box.add_child(field_container)


func _cleanup():
	super()
	if is_instance_valid(field_container):
		field_container.queue_free()
	for node in field_editable_controls:
		if is_instance_valid(node):
			node.queue_free()




#-------------------------------------------------------------------------------
# Property management
#-------------------------------------------------------------------------------


func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
		_update_ui_to_val(final_val)


func _update_ui_to_val(val):
	val = _represented_to_actual(val)
	
	for range_index in range(0, val.size()):
		for value_index in range(0, val[range_index].size()):
			var value_val = val[range_index][value_index]
			field_editable_controls[range_index][value_index].text = str(float(str("%.3f" % value_val)))
	
	super._update_ui_to_val(val.duplicate())


func _string_to_val(string) -> float:
	if string is String:
		if string.is_valid_float():
			return string.to_float()
		else:
			logger.warn("String cannot be converted to float!")
	elif string is float:
		return string
	else:
		logger.warn("Passed variable is not a string or float!")
	return 0.0


func _gather_and_request_prop_action(value_val, range_index, value_index, prop_action_class):
	value_val = _string_to_val(value_val)
	var val = _gather_val()
	
	val[range_index][value_index] = value_val
	
	val = _actual_to_represented(val)
	_request_prop_action(val, prop_action_class)


func _gather_val() -> Array:
	var val := []
	for range_index in range(0, field_editable_controls.size()):
		val.append([])
		for value_index in range(0, field_editable_controls[range_index].size()):
			var value_val = _string_to_val(field_editable_controls[range_index][value_index].text)
			val[range_index].append(value_val)
	return val




#-------------------------------------------------------------------------------
# Input
#-------------------------------------------------------------------------------


func focus_lost(control, range_index, value_index):
	_gather_and_request_prop_action(control.text, range_index, value_index, "PA_PropSet")


# Auto select all text when user clicks inside
func select_line_edit(line_edit:LineEdit, state:bool):
	if state:
		line_edit.call_deferred("select_all")
	else:
		line_edit.call_deferred("deselect")




#-------------------------------------------------------------------------------
# Conversion to/from internal format
#-------------------------------------------------------------------------------


func _represented_to_actual(input):
	var output_array := []
	var range_array := []
	
	if input is Array:
		range_array = input.slice(0, 2)
	else:
		range_array.append(input)
	
	for value_array in range_array:
		var output_value_array := []
		match value_count:
			1:
				if !(value_array is Array):
					output_value_array = [value_array]
				else:
					output_value_array = value_array
			2:
				if representation_type == RepresentationType.VECTOR && value_array is Vector2:
					output_value_array = [value_array.x, value_array.y]
				elif representation_type == RepresentationType.VALUE && value_array is Array:
					output_value_array = value_array.slice(0, 2)
				elif value_array is Array: # this enables correct output_array when passing array-based currentVal as an input
					output_value_array = value_array.slice(0, 2) 
			3:
				if representation_type == RepresentationType.VECTOR && value_array is Vector3:
					output_value_array = [value_array.x, value_array.y, value_array.z]
				elif representation_type == RepresentationType.VALUE && value_array is Array:
					output_value_array = value_array.slice(0, 3) 
				elif value_array is Array: # this enables correct output_array when passing array-based currentVal as an input
					output_value_array = value_array.slice(0, 3) 
			4:
				if value_array is Array:
					output_value_array = value_array.slice(0, 4) 
		
		output_array.append(output_value_array)
	
	return output_array


func _actual_to_represented(range_array:Array):
	var output_array = []
	
	for value_array in range_array:
		var output_value = null
		match value_count:
			1:
				output_value = value_array[0]
			2:
				if representation_type == RepresentationType.VECTOR:
					output_value = Vector2(value_array[0], value_array[1])
				elif representation_type == RepresentationType.VALUE:
					output_value = value_array.slice(0, 1 + 1) 
			3:
				if representation_type == RepresentationType.VECTOR:
					output_value = Vector3(value_array[0], value_array[1], value_array[2])
				elif representation_type == RepresentationType.VALUE:
					output_value = value_array.slice(0, 2 + 1) 
			4:
				if value_array is Array:
					output_value = value_array.slice(0, 3 + 1) 
		
		output_array.append(output_value)
	
	if output_array.size() == 1:
		output_array = output_array[0]
	elif output_array.size() == 0:
		output_array = null
	
	return output_array
