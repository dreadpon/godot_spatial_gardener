tool


const GenericUtils = preload("generic_utils.gd")

const Greenhouse = preload("../../greenhouse/greenhouse.gd")
const Greenhouse_PlantState = preload("../../greenhouse/greenhouse_plant_state.gd")
const Greenhouse_Plant = preload("../../greenhouse/greenhouse_plant.gd")
const Greenhouse_LODVariant = preload("../../greenhouse/greenhouse_LOD_variant.gd")

const PropAction = preload("../../utility/input_field_resource/prop_action.gd")
const PA_PropSet = preload("../../utility/input_field_resource/pa_prop_set.gd")
const PA_PropEdit = preload("../../utility/input_field_resource/pa_prop_edit.gd")
const PA_ArrayInsert = preload("../../utility/input_field_resource/pa_array_insert.gd")
const PA_ArrayRemove = preload("../../utility/input_field_resource/pa_array_remove.gd")
const PA_ArraySet = preload("../../utility/input_field_resource/pa_array_set.gd")




static func snapshot_greenhouse(greenhouse:Greenhouse) -> Dictionary:
	var nested_classes = ["Greenhouse", "Greenhouse_PlantState", "Greenhouse_Plant", "Greenhouse_LODVariant"]
	var snapshot := {}
	snapshot.greenhouse = GenericUtils.gather_properties(greenhouse, nested_classes)
	
	return snapshot


# TODO add a check for both res_edit
static func get_morph_actions(initial:Greenhouse, target:Greenhouse, enable_prop_edit_actions:bool = true) -> Array:
	if !initial || !target: return []
	var morph_actions := []
	
	morph_actions.append_array(get_array_morph_actions(
		target.greenhouse_plant_states, initial.greenhouse_plant_states, 
		[], "plant_types/greenhouse_plant_states"))
	
	for i in range(0, target.greenhouse_plant_states.size()):
		var adrs := ["plant_types/greenhouse_plant_states", i]
		
		var t_plant_state:Greenhouse_PlantState = target.greenhouse_plant_states[i]
		var i_plant_state:Greenhouse_PlantState = Greenhouse_PlantState.new()
		if initial.greenhouse_plant_states.size() > i: 
			i_plant_state = initial.greenhouse_plant_states[i]
		
		morph_actions.append_array(get_prop_morph_actions(
				t_plant_state, i_plant_state, 
				adrs.duplicate(), "plant/plant_brush_active"))
		
		adrs.append("plant/plant")
		
		var t_plant:Greenhouse_Plant = t_plant_state.plant
		var i_plant:Greenhouse_Plant = Greenhouse_Plant.new()
		if i_plant_state: 
			i_plant = i_plant_state.plant
		
		morph_actions.append_array(get_array_morph_actions(
			t_plant.mesh_LOD_variants, i_plant.mesh_LOD_variants, 
			adrs.duplicate(),  "mesh/mesh_LOD_variants"))
		
		for k in range(0, t_plant.mesh_LOD_variants.size()):
			var adrs_1 := adrs.duplicate()
			adrs_1.append_array(["mesh/mesh_LOD_variants", k])
			
			var t_LOD:Greenhouse_LODVariant = t_plant.mesh_LOD_variants[k]
			var i_LOD:Greenhouse_LODVariant = Greenhouse_LODVariant.new()
			if i_plant && i_plant.mesh_LOD_variants.size() > k: 
				i_LOD = i_plant.mesh_LOD_variants[k]
			
			morph_actions.append_array(get_prop_morph_actions(
				t_LOD, i_LOD, 
				adrs_1.duplicate(), "mesh"))
			
			morph_actions.append_array(get_prop_morph_actions(
				t_LOD, i_LOD, 
				adrs_1.duplicate(), "spawned_spatial"))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "mesh/mesh_LOD_max_distance", enable_prop_edit_actions))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "mesh/mesh_LOD_kill_distance", enable_prop_edit_actions))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "mesh/mesh_LOD_max_capacity"))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "mesh/mesh_LOD_min_size", enable_prop_edit_actions))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "density/density_per_units", enable_prop_edit_actions))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "scale/scale_scaling_type"))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "scale/scale_range"))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "up_vector/up_vector_primary_type"))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "up_vector/up_vector_primary"))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "up_vector/up_vector_secondary_type"))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "up_vector/up_vector_secondary"))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "up_vector/up_vector_blending", enable_prop_edit_actions))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "fwd_vector/fwd_vector_primary_type"))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "fwd_vector/fwd_vector_primary"))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "fwd_vector/fwd_vector_secondary_type"))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "fwd_vector/fwd_vector_secondary"))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "fwd_vector/fwd_vector_blending", enable_prop_edit_actions))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "offset/offset_y_range"))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "offset/offset_jitter_fraction", enable_prop_edit_actions))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "rotation/rotation_random_y", enable_prop_edit_actions))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "rotation/rotation_random_x", enable_prop_edit_actions))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "rotation/rotation_random_z", enable_prop_edit_actions))
		
		morph_actions.append_array(get_prop_morph_actions(
			t_plant, i_plant, 
			adrs.duplicate(), "slope/slope_allowed_range"))
	
	return morph_actions


static func get_array_morph_actions(t_array:Array, i_array:Array, adrs:Array, prop:String) -> Array:
	var morph_actions := []
	
	var delta_size = t_array.size() - i_array.size()
	if delta_size > 0:
		for i in range(0, delta_size):
			var index = i_array.size() + i
			morph_actions.append(MorphAction.new(
				adrs, 
				PA_ArrayInsert.new(prop, null, index)))
	elif delta_size < 0:
		for i in range(0, abs(delta_size)):
			
			# TODO add a check for res_edit
			
			var index = i_array.size() - i - 1
			morph_actions.append(MorphAction.new(
				adrs, 
				PA_ArrayRemove.new(prop, null, index)))
	
	return morph_actions


static func get_prop_morph_actions(t_res:Resource, i_res:Resource, adrs:Array, prop:String, edit_beforehand:bool = false):
	var morph_actions := []
	var t_val = t_res.get(prop)
	var i_val = i_res.get(prop)
	
	if !are_props_equal(t_val, i_val):
		if t_val is Array || t_val is Dictionary:
			t_val = t_val.duplicate()
		
		elif t_val is Resource && t_val.has_method("duplicate_ifr"):
			t_val = t_val.duplicate_ifr(false, true)
		
		elif edit_beforehand:
				morph_actions.append(MorphAction.new(
					adrs, 
					PA_PropEdit.new(prop, (t_val - i_val) * 0.5 + t_val)))
		
		morph_actions.append(MorphAction.new(
			adrs, 
			PA_PropSet.new(prop, t_val)))
	
	return morph_actions


static func are_props_equal(t_val, i_val):
	var equal := true
	
	if t_val is Array && i_val is Array:
		if t_val.size() != i_val.size():
			equal = false
		else:
			for i in range(0, t_val.size()):
				if !are_props_equal(t_val[i], i_val[i]):
					equal = false
					break
	elif t_val is Dictionary && i_val is Dictionary:
		if !are_props_equal(t_val.keys(), i_val.keys()) || !are_props_equal(t_val.values(), i_val.values()):
			equal = false
	else:
		equal = t_val == i_val
	
	return equal


static func perform_morph_actions(initial:Greenhouse, morph_actions:Array):
	for morph_action in morph_actions:
		var res = initial
		for address_entry in morph_action.prop_address:
			if res is Array || res is Dictionary:
				res = res[address_entry]
			else:
				res = res.get(address_entry)
		
		res.request_prop_action(morph_action.prop_action.duplicate(true))





class MorphAction:
	var prop_address:Array = []
	var prop_action:Reference = null
	
	
	func _init(_prop_address:Array = [], _prop_action:Reference = null):
		prop_address = _prop_address
		prop_action = _prop_action
	
	
	func _to_string():
		return "[%s:\n	%s]" % [str(prop_address), str(prop_action)]
