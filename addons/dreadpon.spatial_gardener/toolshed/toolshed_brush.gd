tool
extends "../utility/input_field_resource/input_field_resource.gd"


#-------------------------------------------------------------------------------
# All the data that reflects a brush behavior
#-------------------------------------------------------------------------------




const Globals = preload("../utility/globals.gd")

enum BrushType {PAINT, ERASE, SINGLE, REAPPLY}


var behavior_brush_type:int = BrushType.PAINT
var shape_size:float = 1.0
var behavior_strength:float = 1.0




#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


func _init(__behavior_brush_type:int = BrushType.PAINT, __behavior_strength:float = 1.0, __shape_size:float = 1.0).():
	set_meta("class", "Toolshed_Brush")
	resource_name = "Toolshed_Brush"
	
	behavior_brush_type = __behavior_brush_type
	behavior_strength = __behavior_strength
	shape_size = __shape_size


func _create_input_field(_base_control:Control, _resource_previewer, prop:String):
	var input_field:UI_InputField = null
	
	match prop:
		"shape/shape_size":
			var max_value = FunLib.get_setting_safe("dreadpon_spatial_gardener/input_and_ui/brush_size_slider_max_value", 100.0)
			var settings := {"min": 0.0, "max": max_value,  "step": 0.01,  "allow_greater": true,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(shape_size, "Size", prop, settings)
		"behavior/behavior_strength":
			var settings := {"min": 0.0, "max": 1.0,  "step": 0.01,  "allow_greater": false,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(behavior_strength, "Strength", prop, settings)
	
	return input_field




#-------------------------------------------------------------------------------
# Property export
#-------------------------------------------------------------------------------


func _modify_prop(prop:String, val):
	match prop:
		"behavior/behavior_strength":
			val = clamp(val, 0.0, 1.0)
	return val


func _set(prop, val):
	var return_val = true
	val = _modify_prop(prop, val)
	
	match prop:
		"behavior/behavior_brush_type":
			behavior_brush_type = val
			blacklist_for_brush_type()
			property_list_changed_notify()
		"shape/shape_size":
			shape_size = val
		"behavior/behavior_strength":
			behavior_strength = val
		_:
			return_val = false
	
	if return_val:
		emit_changed()
		
	return return_val


func _get(prop):
	match prop:
		"behavior/behavior_brush_type":
			return behavior_brush_type
		"shape/shape_size":
			return shape_size
		"behavior/behavior_strength":
			return behavior_strength
	
	return null


func _get_property_list():
	var prop_dict = _get_prop_dictionary()
	var props := []
	
	for propertyName in _get_properties_for_brush_type():
		props.append(prop_dict[propertyName])
	
	return props


func blacklist_for_brush_type():
	input_field_blacklist = []
	match behavior_brush_type:
		BrushType.SINGLE:
			input_field_blacklist = ["behavior/behavior_strength"]
		BrushType.REAPPLY:
			input_field_blacklist = ["behavior/behavior_strength"]


func _get_prop_dictionary():
	return {
		"behavior/behavior_brush_type" : {
			"name": "behavior/behavior_brush_type",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Paint,Erase,Single,Reapply"
		},
		"shape/shape_size" : {
			"name": "shape/shape_size",
			"type": TYPE_REAL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,50.0,0.01,or_greater"
		},
		"behavior/behavior_strength" : {
			"name": "behavior/behavior_strength",
			"type": TYPE_REAL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1.0,0.01"
		},
	}


func _get_properties_for_brush_type():
	match behavior_brush_type:
		BrushType.PAINT:
			return [
				"behavior/behavior_brush_type", 
				"shape/shape_size",
				"behavior/behavior_strength",
			]
		BrushType.ERASE:
			return [
				"behavior/behavior_brush_type",
				"shape/shape_size",
				"behavior/behavior_strength",
			]
		BrushType.SINGLE:
			return [
				"behavior/behavior_brush_type",
				"shape/shape_size",
			]
		BrushType.REAPPLY:
			return [
				"behavior/behavior_brush_type",
				"shape/shape_size",
			]
	return []


func get_prop_tooltip(prop:String) -> String:
	match prop:
		"behavior/behavior_brush_type":
			return "The brush type enum, that defines it's behavior (paint, erase, etc.)"
		"shape/shape_size":
			return "The diameter of this brush, in world units\n" \
				+ "Can be edited by holding 'brush_property_edit_button' and dragging in the editor viewport\n" \
				+ Globals.AS_IN_SETTINGS_STRING
		"behavior/behavior_strength":
			return "The plant density multiplier of this brush\n" \
				+ "Can be edited by holding 'brush_property_edit_modifier_key' + 'brush_property_edit_button' and dragging in the editor viewport\n" \
				+ Globals.AS_IN_SETTINGS_STRING
	return ""
