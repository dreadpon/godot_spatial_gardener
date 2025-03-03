@tool
extends "../utility/input_field_resource/input_field_resource.gd"


#-------------------------------------------------------------------------------
# All the data that reflects a brush behavior
#-------------------------------------------------------------------------------




const Globals = preload("../utility/globals.gd")
const Transplanter = preload("../transplanter/transplanter.gd")

enum BrushType {PAINT, ERASE, SINGLE, REAPPLY, TRANSFORM}
enum OverlapMode {VOLUME, PROJECTION}
enum BrushShape {SPHERE, CIRCLE, POINTER}

var behavior_brush_type:int = BrushType.PAINT
var shape_volume_size:float = 1.0
var shape_projection_size:float = 1.0
var behavior_strength:float = 1.0
var behavior_passthrough: bool = false
var behavior_overlap_mode: int = OverlapMode.VOLUME
var behavior_no_settings_text: String = 'This brush has no additional settings'

var behavior_selection_mode: int = Transplanter.QueryMode.MESH
var behavior_selection_collision_mask: int = 1
var behavior_enable_selection_preprocess: bool = true




#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


func _init(
	__behavior_brush_type:int = BrushType.PAINT, __behavior_strength:float = 1.0, __shape_volume_size:float = 1.0,
	__shape_projection_size:float = 1.0, __behavior_passthrough: bool = false, __behavior_overlap_mode: int = OverlapMode.VOLUME,
	__behavior_selection_mode: int = Transplanter.QueryMode.MESH, __behavior_selection_collision_mask: int = 1, __behavior_enable_selection_preprocess: bool = true
	):
	
	input_field_blacklist = ['behavior/behavior_brush_type']
	
	super()
	set_meta("class", "Toolshed_Brush")
	resource_name = "Toolshed_Brush"
	
	behavior_brush_type = __behavior_brush_type
	behavior_strength = __behavior_strength
	shape_volume_size = __shape_volume_size
	shape_projection_size = __shape_projection_size
	behavior_passthrough = __behavior_passthrough
	behavior_overlap_mode = __behavior_overlap_mode
	behavior_selection_mode = __behavior_selection_mode
	behavior_selection_collision_mask = __behavior_selection_collision_mask
	behavior_enable_selection_preprocess = __behavior_enable_selection_preprocess


func _create_input_field(_base_control:Control, _resource_previewer, prop:String) -> UI_InputField:
	var input_field:UI_InputField = null
	match prop:
		"shape/shape_volume_size":
			var max_value = FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/brush_volume_size_slider_max_value", 100.0)
			var settings := {"min": 0.0, "max": max_value,  "step": 0.01,  "allow_greater": true,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(shape_volume_size, "Volume Size", prop, settings)
		"shape/shape_projection_size":
			var max_value = FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/brush_projection_size_slider_max_value", 1000.0)
			var settings := {"min": 1.0, "max": max_value,  "step": 1.0,  "allow_greater": true,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(shape_projection_size, "Projection Size", prop, settings)
		"behavior/behavior_strength":
			var settings := {"min": 0.0, "max": 1.0,  "step": 0.01,  "allow_greater": false,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(behavior_strength, "Strength", prop, settings)
		"behavior/behavior_passthrough":
			input_field = UI_IF_Bool.new(behavior_passthrough, "Passthrough", prop)
		"behavior/behavior_overlap_mode":
			var settings := {"enum_list": FunLib.capitalize_string_array(OverlapMode.keys())}
			input_field = UI_IF_Enum.new(behavior_overlap_mode, "Overlap Mode", prop, settings)
		"behavior/behavior_no_settings_text":
			var settings := {"label_visibility": false}
			input_field = UI_IF_PlainText.new(behavior_no_settings_text, "No Settings Text", prop, settings)
		"behavior/behavior_selection_mode":
			var settings := {"enum_list": FunLib.capitalize_string_array(Transplanter.QueryMode.keys())}
			input_field = UI_IF_Enum.new(behavior_selection_mode, "Selection Mode", prop, settings)
		"behavior/behavior_selection_collision_mask":
			var settings := {"hint": PROPERTY_HINT_LAYERS_3D_PHYSICS}#, "name_list": []}
			input_field = UI_IF_IntFlags.new(behavior_selection_mode, "Selection Mask", prop, settings)
		"behavior/behavior_enable_selection_preprocess":
			input_field = UI_IF_Bool.new(behavior_enable_selection_preprocess, "Preprocess Selection", prop)
	
	return input_field




#-------------------------------------------------------------------------------
# Property export
#-------------------------------------------------------------------------------


func _modify_prop(prop:String, val):
	match prop:
		"behavior/behavior_strength":
			val = clamp(val, 0.0, 1.0)
		"behavior/behavior_overlap_mode":
			match behavior_brush_type:
				BrushType.PAINT, BrushType.SINGLE:
					val = OverlapMode.VOLUME
		"shape/shape_volume_size":
			match behavior_brush_type:
				BrushType.SINGLE:
					val = 1.0
	return val


func _set(prop, val):
	var return_val = true
	val = _modify_prop(prop, val)
	
	match prop:
		"behavior/behavior_brush_type":
			behavior_brush_type = val
			_emit_property_list_changed_notify()
		"shape/shape_volume_size":
			shape_volume_size = val
		"shape/shape_projection_size":
			shape_projection_size = val
		"behavior/behavior_strength":
			behavior_strength = val
		"behavior/behavior_passthrough":
			behavior_passthrough = val
		"behavior/behavior_overlap_mode":
			behavior_overlap_mode = val
			_emit_property_list_changed_notify()
		"behavior/behavior_no_settings_text":
			behavior_no_settings_text = val
		"behavior/behavior_selection_mode":
			behavior_selection_mode = val
			_emit_property_list_changed_notify()
		"behavior/behavior_selection_collision_mask":
			behavior_selection_collision_mask = val
		"behavior/behavior_enable_selection_preprocess":
			behavior_enable_selection_preprocess = val
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
		"behavior/behavior_passthrough":
			return behavior_passthrough
		"behavior/behavior_overlap_mode":
			return behavior_overlap_mode
		"behavior/behavior_no_settings_text":
			return behavior_no_settings_text
		"behavior/behavior_selection_mode":
			return behavior_selection_mode
		"behavior/behavior_selection_collision_mask":
			return behavior_selection_collision_mask
		"behavior/behavior_enable_selection_preprocess":
			return behavior_enable_selection_preprocess
	
	return null


func _filter_prop_dictionary(prop_dict: Dictionary) -> Dictionary:
	var props_to_hide := ["behavior/behavior_brush_type"]
	
	match behavior_brush_type:
		BrushType.TRANSFORM:
			props_to_hide.append_array([
				"behavior/behavior_brush_type",
				"shape/shape_volume_size",
				"shape/shape_projection_size",
				"behavior/behavior_strength",
				"behavior/behavior_passthrough",
				"behavior/behavior_overlap_mode",
				"behavior/behavior_no_settings_text"
			])
			match behavior_selection_mode:
				Transplanter.QueryMode.MESH, Transplanter.QueryMode.NODE3D_FIRST_MESH:
					props_to_hide.append_array([
						"behavior/behavior_selection_collision_mask"
					])
				_:
					props_to_hide.append_array([
						"behavior/behavior_enable_selection_preprocess"
					])
	
	match behavior_overlap_mode:
		OverlapMode.VOLUME:
			match behavior_brush_type:
				BrushType.PAINT:
					props_to_hide.append_array([
						"shape/shape_projection_size",
						"behavior/behavior_passthrough",
						"behavior/behavior_overlap_mode",
						"behavior/behavior_no_settings_text",
						"behavior/behavior_selection_mode",
						"behavior/behavior_selection_collision_mask",
						"behavior/behavior_enable_selection_preprocess"
					])
				BrushType.ERASE:
					props_to_hide.append_array([
						"shape/shape_projection_size",
						"behavior/behavior_passthrough",
						"behavior/behavior_no_settings_text",
						"behavior/behavior_selection_mode",
						"behavior/behavior_selection_collision_mask",
						"behavior/behavior_enable_selection_preprocess"
					])
				BrushType.SINGLE:
					props_to_hide.append_array([
						"shape/shape_volume_size",
						"shape/shape_projection_size",
						"behavior/behavior_strength",
						"behavior/behavior_passthrough",
						"behavior/behavior_overlap_mode",
						"behavior/behavior_selection_mode",
						"behavior/behavior_selection_collision_mask",
						"behavior/behavior_enable_selection_preprocess"
					])
				BrushType.REAPPLY:
					props_to_hide.append_array([
						"shape/shape_projection_size",
						"behavior/behavior_passthrough",
						"behavior/behavior_no_settings_text",
						"behavior/behavior_selection_mode",
						"behavior/behavior_selection_collision_mask",
						"behavior/behavior_enable_selection_preprocess"
					])
		OverlapMode.PROJECTION:
			match behavior_brush_type:
				BrushType.ERASE:
					props_to_hide.append_array([
						"shape/shape_volume_size",
						"behavior/behavior_strength",
						"behavior/behavior_no_settings_text",
						"behavior/behavior_selection_mode",
						"behavior/behavior_selection_collision_mask",
						"behavior/behavior_enable_selection_preprocess"
					])
				BrushType.REAPPLY:
					props_to_hide.append_array([
						"shape/shape_volume_size",
						"behavior/behavior_strength",
						"behavior/behavior_no_settings_text",
						"behavior/behavior_selection_mode",
						"behavior/behavior_selection_collision_mask",
						"behavior/behavior_enable_selection_preprocess"
					])
	
	for prop in props_to_hide:
		prop_dict[prop].usage = PROPERTY_USAGE_NO_EDITOR
	
	return prop_dict


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
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,100.0,0.01,or_greater"
		},
		"shape/shape_projection_size" : {
			"name": "shape/shape_projection_size",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1.0,1000.0,1.0,or_greater"
		},
		"behavior/behavior_strength" : {
			"name": "behavior/behavior_strength",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1.0,0.01"
		},
		"behavior/behavior_passthrough" : {
			"name": "behavior/behavior_passthrough",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
		},
		"behavior/behavior_overlap_mode" : {
			"name": "behavior/behavior_overlap_mode",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Volume,Projection"
		},
		"behavior/behavior_no_settings_text" : {
			"name": "behavior/behavior_no_settings_text",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
		},
		"behavior/behavior_selection_mode" : {
			"name": "behavior/behavior_selection_mode",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Mesh,Node3D First Mesh, Node3D Body"
		},
		"behavior/behavior_selection_collision_mask" : {
			"name": "behavior/behavior_selection_collision_mask",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_LAYERS_3D_PHYSICS,
		},
		"behavior/behavior_enable_selection_preprocess" : {
			"name": "behavior/behavior_enable_selection_preprocess",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
		},
	}


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
		"behavior/behavior_passthrough":
			return "The flag, that defines whether this brush can affect plants hidden behind terrain\n" \
				+ "Only active physics bodies masked by 'Gardening Collision Mask' can occlude plants\n" \
				+ "In simpler terms: whatever surface volume-brush sticks to, will block a projection-brush as well\n" \
				+ "\n" \
				+ "Enabling Passthrough will allow this brush to ignore any collision whatsoever\n" \
				+ "It also gives better performance when painting since it disables additional collision checks\n"
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
		"behavior/behavior_selection_mode":
			return "The selection mode flag\n" \
				+ "Defines which LOD parameters are used to select placed instances\n" \
				+ "\n" \
				+ "\"Mesh\" uses LOD \"Mesh\" field, selection will ignore physics bodies\n" \
				+ "\"Node3D First Mesh\" searches LOD \"Spawned Node3D\" field for the first MeshInstance3D it encounters\n" \
				+ "	and uses its \"Mesh\" field, selection will ignore physics bodies\n" \
				+ "\"Node3D Body\" performs a physics raycast (Spawned Node3D needs to contain a PhysicsBody),\n" \
				+ "	will ignore anything that isn't a \"PhysicsBody3D\"\n" \
				+ "\n"
		"behavior/behavior_selection_collision_mask":
			return "A physics selection mask to use for physics raycasts\n" \
				+ "\n"
		"behavior/behavior_enable_selection_preprocess":
			return "The flag, that defines whether selection results should be filtered beforehand\n" \
				+ "\n" \
				+ "Disabling this flag allows to select instances through other objects\n" \
				+ "Enabling performs basic occlusion tests (separate for Meshes and PhysicsBodies) to reject occluded instances\n" \
				+ "When \"Selection Mode\" is set to \"Mesh\" or \"Node3D First Mesh\", occlusion tests are performed only on\n" \
				+ "CSGShape3D, MeshInstance3D and MultiMeshINstance3D\n" \
				+ "\n"
	return ""
