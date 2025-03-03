@tool
extends "../utility/input_field_resource/input_field_resource.gd"


#-------------------------------------------------------------------------------
# All the data that configures how Bake to Nodes should behave
#-------------------------------------------------------------------------------

enum LODPickingType { MANUAL, CURRENT_CAMERA, SCENE_ORIGIN, NONE }

var mesh_lod_picking: LODPickingType = LODPickingType.MANUAL
var mesh_lod_idx: int = 0
var mesh_kill_instances: bool = true
var node3d_lod_picking: LODPickingType = LODPickingType.MANUAL
var node3d_lod_idx: int = 0
var node3d_kill_instances: bool = true

var lod_max_idx: int = 0




#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


func _init(
	p_lod_max_idx: int = 0,
	p_mesh_lod_picking: LODPickingType = LODPickingType.MANUAL, p_mesh_lod_idx: int = 0, p_mesh_kill_instances: bool = true,
	p_node3d_lod_picking: LODPickingType = LODPickingType.MANUAL, p_node3d_lod_idx: int = 0, p_node3d_kill_instances: bool = true
	):
	
	super()
	set_meta("class", "BakerPlantSettings")
	resource_name = "Baker Plant Settings"
	
	lod_max_idx = p_lod_max_idx
	
	mesh_lod_picking = p_mesh_lod_picking
	mesh_lod_idx = p_mesh_lod_idx
	mesh_kill_instances = p_mesh_kill_instances
	node3d_lod_picking = p_node3d_lod_picking
	node3d_lod_idx = p_node3d_lod_idx
	node3d_kill_instances = p_node3d_kill_instances


func _create_input_field(_base_control:Control, _resource_previewer, prop:String) -> UI_InputField:
	var input_field:UI_InputField = null
	match prop:
		"mesh/mesh_lod_picking":
			var settings := {"enum_list": FunLib.capitalize_string_array(LODPickingType.keys())}
			input_field = UI_IF_Enum.new(mesh_lod_picking, "Mesh LOD Picking", prop, settings)
		"mesh/mesh_lod_idx":
			var settings := {"min": 0, "max": lod_max_idx,  "step": 1,  "allow_greater": false,  "allow_lesser": false,}
			input_field = UI_IF_IntSlider.new(mesh_lod_idx, "Mesh LOD Index", prop, settings)
		"mesh/mesh_kill_instances":
			input_field = UI_IF_Bool.new(mesh_kill_instances, "Mesh Kill Instances", prop)
		"node3d/node3d_lod_picking":
			var settings := {"enum_list": FunLib.capitalize_string_array(LODPickingType.keys())}
			input_field = UI_IF_Enum.new(node3d_lod_picking, "Node3D LOD Picking", prop, settings)
		"node3d/node3d_lod_idx":
			var settings := {"min": 0, "max": lod_max_idx,  "step": 1,  "allow_greater": false,  "allow_lesser": false,}
			input_field = UI_IF_IntSlider.new(node3d_lod_idx, "Node3D LOD Index", prop, settings)
		"node3d/node3d_kill_instances":
			input_field = UI_IF_Bool.new(node3d_kill_instances, "Node3D Kill Instances", prop)
	
	return input_field




#-------------------------------------------------------------------------------
# Property export
#-------------------------------------------------------------------------------


func _modify_prop(prop:String, val):
	match prop:
		"mesh/mesh_lod_idx":
			val = clamp(roundi(val), 0, lod_max_idx)
		"node3d/node3d_lod_idx":
			val = clamp(roundi(val), 0, lod_max_idx)
	return val


func _set(prop, val):
	var return_val = true
	val = _modify_prop(prop, val)
	
	match prop:
		"mesh/mesh_lod_picking":
			mesh_lod_picking = val
			_emit_property_list_changed_notify()
		"mesh/mesh_lod_idx":
			mesh_lod_idx = val
		"mesh/mesh_kill_instances":
			mesh_kill_instances = val
		"node3d/node3d_lod_picking":
			node3d_lod_picking = val
			_emit_property_list_changed_notify()
		"node3d/node3d_lod_idx":
			node3d_lod_idx = val
		"node3d/node3d_kill_instances":
			node3d_kill_instances = val
		_:
			return_val = false
	
	if return_val:
		emit_changed()
	
	return return_val


func _get(prop):
	match prop:
		"mesh/mesh_lod_picking":
			return mesh_lod_picking
		"mesh/mesh_lod_idx":
			return mesh_lod_idx
		"mesh/mesh_kill_instances":
			return mesh_kill_instances
		"node3d/node3d_lod_picking":
			return node3d_lod_picking
		"node3d/node3d_lod_idx":
			return node3d_lod_idx
		"node3d/node3d_kill_instances":
			return node3d_kill_instances
	
	return null


func _filter_prop_dictionary(prop_dict: Dictionary) -> Dictionary:
	var props_to_hide := []
	
	match mesh_lod_picking:
		LODPickingType.CURRENT_CAMERA, LODPickingType.SCENE_ORIGIN:
			props_to_hide.append_array([
				"mesh/mesh_lod_idx"
			])
		LODPickingType.NONE:
			props_to_hide.append_array([
				"mesh/mesh_lod_idx",
				"mesh/mesh_kill_instances"
			])
	
	match node3d_lod_picking:
		LODPickingType.CURRENT_CAMERA, LODPickingType.SCENE_ORIGIN:
			props_to_hide.append_array([
				"node3d/node3d_lod_idx"
			])
		LODPickingType.NONE:
			props_to_hide.append_array([
				"node3d/node3d_lod_idx",
				"node3d/node3d_kill_instances"
			])
	
	for prop in props_to_hide:
		prop_dict[prop].usage = PROPERTY_USAGE_NO_EDITOR
	
	return prop_dict


func _get_prop_dictionary():
	return {
		"mesh/mesh_lod_picking" : {
			"name": "mesh/mesh_lod_picking",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Manual,Current Camera,Scene Origin,None"
		},
		"mesh/mesh_lod_idx" : {
			"name": "mesh/mesh_lod_idx",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,%d,1" % [lod_max_idx],
		},
		"mesh/mesh_kill_instances" : {
			"name": "mesh/mesh_kill_instances",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
		},
		"node3d/node3d_lod_picking" : {
			"name": "node3d/node3d_lod_picking",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Manual,Current Camera,Scene Origin,None"
		},
		"node3d/node3d_lod_idx" : {
			"name": "node3d/node3d_lod_idx",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,%d,1" % [lod_max_idx],
		},
		"node3d/node3d_kill_instances" : {
			"name": "node3d/node3d_kill_instances",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
		},
	}


func get_prop_tooltip(prop:String) -> String:
	match prop:
		"mesh/mesh_lod_picking":
			return "Picking criteria for LOD \"Mesh\" fields\n" \
				+ "\n" \
				+ "\"Manual\" - choose a specific LOD by its index (starts from zero)\n" \
				+ "\"Current Camera\" - use LODs as they are assigned around the current/editor camera\n" \
				+ "\"Scene Origin\" - use LODs as if the camera was at scene origin coordinates (0, 0, 0)\n" \
				+ "\"None\" - do not bake meshes for this plant\n" \
				+ "\n"
		"mesh/mesh_lod_idx":
			return "LOD at which index to use for LOD \"Mesh\" baking (starts from zero)\n" \
				+ "\n"
		"mesh/mesh_kill_instances":
			return "Whether \"Mesh\" instances farther than \"LOD Kill Distance\"\n" \
				+ "Should be culled/killed on bake or kept regardless\n" \
				+ "\n"
		"node3d/node3d_lod_picking":
			return "Picking criteria for LOD \"Spawned Node3D\" fields\n" \
				+ "\n" \
				+ "\"Manual\" - choose a specific LOD by its index (starts from zero)\n" \
				+ "\"Current Camera\" - use LODs as they are assigned around the current/editor camera\n" \
				+ "\"Scene Origin\" - use LODs as if the camera was at scene origin coordinates (0, 0, 0)\n" \
				+ "\"None\" - do not bake node3Ds for this plant\n" \
				+ "\n"
		"node3d/node3d_lod_idx":
			return "LOD at which index to use for LOD \"Spawned Node3D\" baking (starts from zero)\n" \
				+ "\n"
		"node3d/node3d_kill_instances":
			return "Whether \"Spawned Node3D\" instances farther than \"LOD Kill Distance\"\n" \
				+ "Should be culled/killed on bake or kept regardless\n" \
				+ "\n"
	
	return ""
