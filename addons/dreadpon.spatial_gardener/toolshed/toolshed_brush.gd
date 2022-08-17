tool
extends "../utility/input_field_resource/input_field_resource.gd"


#-------------------------------------------------------------------------------
# All the data that reflects a brush behavior
#-------------------------------------------------------------------------------




const Globals = preload("../utility/globals.gd")

enum BrushType {PAINT, ERASE, SINGLE, REAPPLY}
enum OverlapMode {VOLUME, PROJECTION}


var behavior_brush_type:int = BrushType.PAINT
var shape_volume_size:float = 1.0
var shape_projection_size:float = 10.0
var behavior_strength:float = 1.0
var behavior_overlap_mode: int = OverlapMode.VOLUME




#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


func _init(__behavior_brush_type:int = BrushType.PAINT, __behavior_strength:float = 1.0, __shape_volume_size:float = 1.0, __shape_projection_size:float = 1.0, __behavior_overlap_mode: int = OverlapMode.VOLUME).():
	set_meta("class", "Toolshed_Brush")
	resource_name = "Toolshed_Brush"
	
	behavior_brush_type = __behavior_brush_type
	behavior_strength = __behavior_strength
	shape_volume_size = __shape_volume_size
	shape_projection_size = __shape_projection_size
	behavior_overlap_mode = __behavior_overlap_mode


func _create_input_field(_base_control:Control, _resource_previewer, prop:String):
	var input_field:UI_InputField = null
	
	match prop:
		"shape/shape_volume_size":
			var max_value = FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/brush_volume_size_slider_max_value", 100.0)
			var settings := {"min": 0.0, "max": max_value,  "step": 0.01,  "allow_greater": true,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(shape_volume_size, "Volume Size", prop, settings)
			input_field.add_tracked_property("behavior/behavior_overlap_mode", OverlapMode.VOLUME, behavior_overlap_mode)
			input_field.set_visibility_is_tracked(true)
		"shape/shape_projection_size":
			var max_value = FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/brush_projection_size_slider_max_value", 100.0)
			var settings := {"min": 1.0, "max": max_value,  "step": 1.0,  "allow_greater": true,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(shape_projection_size, "Projection Size", prop, settings)
			input_field.add_tracked_property("behavior/behavior_overlap_mode", OverlapMode.PROJECTION, behavior_overlap_mode)
			input_field.set_visibility_is_tracked(true)
		"behavior/behavior_strength":
			var settings := {"min": 0.0, "max": 1.0,  "step": 0.01,  "allow_greater": false,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(behavior_strength, "Strength", prop, settings)
			input_field.add_tracked_property("behavior/behavior_overlap_mode", OverlapMode.VOLUME, behavior_overlap_mode)
			input_field.set_visibility_is_tracked(true)
		"behavior/behavior_overlap_mode":
			var settings := {"enum_list": FunLib.capitalize_string_array(OverlapMode.keys())}
			input_field = UI_IF_Enum.new(behavior_overlap_mode, "Overlap Mode", prop, settings)
	
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
			blacklist_input_fields()
			property_list_changed_notify()
		"shape/shape_volume_size":
			shape_volume_size = val
		"shape/shape_projection_size":
			shape_projection_size = val
		"behavior/behavior_strength":
			behavior_strength = val
		"behavior/behavior_overlap_mode":
			behavior_overlap_mode = val
			blacklist_input_fields()
			property_list_changed_notify()
		_:
			return_val = false
	
	if return_val:
		emit_changed()
		
	return return_val


func _get(prop):
	match prop:
		"behavior/behavior_brush_type":
			return behavior_brush_type
		"shape/shape_volume_size":
			return shape_volume_size
		"shape/shape_projection_size":
			return shape_projection_size
		"behavior/behavior_strength":
			return behavior_strength
		"behavior/behavior_overlap_mode":
			return behavior_overlap_mode
	
	return null


func _get_property_list():
	var prop_dict = _get_prop_dictionary()
	var props := []
	
	for propertyName in _get_properties_for_brush_type():
		props.append(prop_dict[propertyName])
	
	return props


func blacklist_input_fields():
	input_field_blacklist = []
	match behavior_brush_type:
		BrushType.SINGLE:
			input_field_blacklist.append("behavior/behavior_strength")
		BrushType.REAPPLY:
			input_field_blacklist.append("behavior/behavior_strength")
	match behavior_overlap_mode:
		OverlapMode.PROJECTION:
			if !input_field_blacklist.has("behavior/behavior_strength"):
				input_field_blacklist.append("behavior/behavior_strength")


func _get_prop_dictionary():
	return {
		"behavior/behavior_brush_type" : {
			"name": "behavior/behavior_brush_type",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Paint,Erase,Single,Reapply"
		},
		"shape/shape_volume_size" : {
			"name": "shape/shape_volume_size",
			"type": TYPE_REAL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,100.0,0.01,or_greater"
		},
		"shape/shape_projection_size" : {
			"name": "shape/shape_projection_size",
			"type": TYPE_REAL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1000.0,1.0,or_greater"
		},
		"behavior/behavior_strength" : {
			"name": "behavior/behavior_strength",
			"type": TYPE_REAL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1.0,0.01"
		},
		"behavior/behavior_overlap_mode" : {
			"name": "behavior/behavior_overlap_mode",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Volume,Projection"
		},
	}


func _get_properties_for_brush_type():
	var props = [
		"behavior/behavior_brush_type",
		"shape/shape_volume_size",
		"shape/shape_projection_size",
		"behavior/behavior_overlap_mode"]
	
	match behavior_brush_type:
		BrushType.PAINT, BrushType.ERASE:
			props.append_array([
				"behavior/behavior_strength",
			])
	
	return props


func get_prop_tooltip(prop:String) -> String:
	match prop:
		"behavior/behavior_brush_type":
			return "The brush type enum, that defines it's behavior (paint, erase, etc.)"
		"shape/shape_volume_size":
			return "The diameter of this brush, in world units\n" \
				+ "\n" \
				+ "Can be edited by dragging in the editor viewport while holding\n" \
				+ "[brush_prop_edit_button]\n" \
				+ Globals.AS_IN_SETTINGS_STRING
		"shape/shape_projection_size":
			return "The diameter of this brush, in screen pixels\n" \
				+ "\n" \
				+ "Can be edited by dragging in the editor viewport while holding\n" \
				+ "[brush_prop_edit_button]\n" \
				+ Globals.AS_IN_SETTINGS_STRING
		"behavior/behavior_strength":
			return "The plant density multiplier of this brush\n" \
				+ "\n" \
				+ "Can be edited by dragging in the editor viewport while holding\n" \
				+ "[brush_prop_edit_modifier] + [brush_prop_edit_button]\n" \
				+ Globals.AS_IN_SETTINGS_STRING
		"behavior/behavior_overlap_mode":
			return "The overlap mode enum, that defines how brush finds which plants to affect\n" \
				+ "Volume brush exists in 3D world and affects whichever plants it overlaps\n" \
				+ "Projection brush exists in screen-space and affects all plants that are visually inside it's area\n" \
				+ "\n" \
				+ "For normal painting use a Volumetric brush\n" \
				+ "If you have plants stuck in mid-air (say, you moved the ground beneath them),\n" \
				+ "Use a Projection brush to remove them (Volumetric brush simply won't reach them)\n" \
				+ "\n" \
				+ "Can be edited by pressing\n" \
				+ "[brush_overlap_mode_button]\n" \
				+ Globals.AS_IN_SETTINGS_STRING
	return ""
