tool
extends "../utility/input_field_resource/input_field_resource.gd"


#-------------------------------------------------------------------------------
# A storage object for meshes to be shown as plants
# And spatials to be spawned at their position (typically a StaticBody)
#-------------------------------------------------------------------------------


var Globals = preload("../utility/globals.gd")

var mesh:Mesh = null
var spawned_spatial:PackedScene = null
# Toggle for shadow casting mode on multimeshes
var cast_shadow:int = GeometryInstance.SHADOW_CASTING_SETTING_ON



#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


func _init(__mesh:Mesh = null, __spawned_spatial:PackedScene = null):
	set_meta("class", "Greenhouse_LODVariant")
	resource_name = "Greenhouse_LODVariant"
	
	mesh = __mesh
	spawned_spatial = __spawned_spatial


func _create_input_field(_base_control:Control, _resource_previewer, prop:String):
	var input_field:UI_InputField = null
	
	match prop:
		"mesh":
			var settings := {
				"_base_control": _base_control,
				# Godot really needs a proper class check
				"accepted_classes": Globals.MESH_CLASSES,
				"element_display_size": 75 * FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/greenhouse_thumbnail_scale", 1.0),
				"element_interaction_flags": UI_IF_ThumbnailArray.PRESET_RESOURCE,
				"_resource_previewer": _resource_previewer,
				}
			input_field = UI_IF_ThumbnailObject.new(mesh, "Mesh", prop, settings)
		"spawned_spatial":
			var settings := {
				"_base_control": _base_control,
				"accepted_classes": ["PackedScene"],
				"element_display_size": 75 * FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/greenhouse_thumbnail_scale", 1.0),
				"element_interaction_flags": UI_IF_ThumbnailArray.PRESET_RESOURCE,
				"_resource_previewer": _resource_previewer,
				}
			input_field = UI_IF_ThumbnailObject.new(spawned_spatial, "Spawned Spatial", prop, settings)
		"cast_shadow":
			var settings := {"enum_list": ["Off", "On", "Double-Sided", "Shadows Only"]}
			input_field = UI_IF_Enum.new(cast_shadow, "Shadow Casting Mode", prop, settings)
	
	return input_field




#-------------------------------------------------------------------------------
# Property export
#-------------------------------------------------------------------------------


func _set(prop, val):
	var return_val = true
	val = _modify_prop(prop, val)
	
	match prop:
		"mesh":
			mesh = val
		"spawned_spatial":
			spawned_spatial = val
		"cast_shadow":
			cast_shadow = val
		_:
			return_val = false
	
	if return_val:
		emit_changed()
		
	return return_val


func _get(prop):
	match prop:
		"mesh":
			return mesh
		"spawned_spatial":
			return spawned_spatial
		"cast_shadow":
			return cast_shadow
	
	return null


func _get_prop_dictionary():
	return {
		"mesh" : {
			"name": "mesh",
			"type": TYPE_OBJECT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
		},
		"spawned_spatial" : {
			"name": "spawned_spatial",
			"type": TYPE_OBJECT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
		},
		"cast_shadow":
		{
			"name": "cast_shadow",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Off,On,Double-Sided,Shadows Only"
		}
	}


func get_prop_tooltip(prop:String) -> String:
	match prop:
		"mesh":
			return "The mesh (.mesh) resource used to display the plant"
		"spawned_spatial":
			return "The PackedScene (assumed to be Spatial) that spawns alongside the mesh\n" \
				+ "They are separate because mesh rendering is optimized using Godot's MultiMesh\n" \
				+ "Spawned Spatials are used to define custom behavior (excluding rendering) for each instance, mainly collision\n" \
				+ "This should be used sparingly, as thousands of physics bodies will surely approach a limit of what Godot can handle\n" \
				+ "\n" \
				+ "NOTE: switching LODs with Spawned Spatials can be expensive due to removing and adding hundreds of nodes at once\n" \
				+ "But if all your LODs reference the same PackedScene - they will persist across the LOD changes and won't cause any lag spikes\n" \
				+ "The alternative would be to optimise yout octrees to contain only a small amount of Spawned Spatials - 10-20 at most\n" \
				+ "Then the process of switching LODs will go a lot smoother"
		"cast_shadow":
			return "Shadow casting mode for this specific LOD\n" \
				+ "Disabling shadow casting slightly improves performance and is recommended for higher LODs (those further away)"
	return ""
