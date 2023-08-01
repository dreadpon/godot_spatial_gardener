@tool


const GenericUtils = preload("generic_utils.gd")

const Greenhouse = preload("res://addons/dreadpon.spatial_gardener/greenhouse/greenhouse.gd")
const Greenhouse_PlantState = preload("res://addons/dreadpon.spatial_gardener/greenhouse/greenhouse_plant_state.gd")
const Greenhouse_Plant = preload("res://addons/dreadpon.spatial_gardener/greenhouse/greenhouse_plant.gd")
const Greenhouse_LODVariant = preload("res://addons/dreadpon.spatial_gardener/greenhouse/greenhouse_LOD_variant.gd")

const PropAction = preload("res://addons/dreadpon.spatial_gardener/utility/input_field_resource/prop_action.gd")
const PA_PropSet = preload("res://addons/dreadpon.spatial_gardener/utility/input_field_resource/pa_prop_set.gd")
const PA_PropEdit = preload("res://addons/dreadpon.spatial_gardener/utility/input_field_resource/pa_prop_edit.gd")
const PA_ArrayInsert = preload("res://addons/dreadpon.spatial_gardener/utility/input_field_resource/pa_array_insert.gd")
const PA_ArrayRemove = preload("res://addons/dreadpon.spatial_gardener/utility/input_field_resource/pa_array_remove.gd")
const PA_ArraySet = preload("res://addons/dreadpon.spatial_gardener/utility/input_field_resource/pa_array_set.gd")




static func snapshot_greenhouse(greenhouse:Greenhouse) -> Dictionary:
	var nested_classes = ["Greenhouse", "Greenhouse_PlantState", "Greenhouse_Plant", "Greenhouse_LODVariant"]
	var snapshot := {}
	snapshot.greenhouse = GenericUtils.gather_properties(greenhouse, nested_classes)
	
	return snapshot


static func get_morph_actions(initial:Greenhouse, target:Greenhouse, enable_prop_edit_actions:bool = true) -> Array:
	if !initial || !target: return []
	var nested_prop_name_classes := {
		"plant_types/greenhouse_plant_states": "Greenhouse_PlantState", 
		"plant/plant": "Greenhouse_Plant", 
		"mesh/mesh_LOD_variants": "Greenhouse_LODVariant"}
	var morph_actions := []
	
	get_morph_actions_recursive(
		initial.greenhouse_plant_states, target.greenhouse_plant_states, [], "plant_types/greenhouse_plant_states",
		nested_prop_name_classes, morph_actions, enable_prop_edit_actions)
	
	return morph_actions


static func get_morph_actions_recursive(initial, target, address:Array, prop_name, nested_prop_name_classes:Dictionary, morph_actions: Array, enable_prop_edit_actions:bool = true):
	if is_instance_of(target, Object):
		if target.has_meta("class") && nested_prop_name_classes.values().has(target.get_meta("class")):
			for nested_prop in target._get_prop_dictionary():
				var t_next = target.get(nested_prop)
				var i_next = initial.get(nested_prop)
				var next_address = address.duplicate()
				next_address.append_array([prop_name])
				get_morph_actions_recursive(i_next, t_next, next_address.duplicate(), nested_prop, nested_prop_name_classes, morph_actions, enable_prop_edit_actions)
		else:
			morph_actions.append_array(get_prop_morph_actions(
				target, initial, address.duplicate(), prop_name, false))
	
	elif target is Array && nested_prop_name_classes.has(prop_name):
		morph_actions.append_array(get_array_morph_actions(
			target, initial, address.duplicate(), prop_name))
		for idx in range(0, target.size()):
			var t_next = target[idx]
			var i_next = null
			if initial.size() > idx:
				i_next = initial[idx]
			elif nested_prop_name_classes.has(prop_name):
				i_next = mk_object_for_class(nested_prop_name_classes[prop_name])
			
			var next_address = address.duplicate()
			next_address.append_array([prop_name])
			get_morph_actions_recursive(i_next, t_next, next_address, idx, nested_prop_name_classes, morph_actions, enable_prop_edit_actions)
	
#	elif target is Dictionary:
#		pass
	
	else:
		var do_edit_actions = false
		if typeof(target) == typeof(initial) && typeof(target) == TYPE_FLOAT:
			do_edit_actions = enable_prop_edit_actions
		
		morph_actions.append_array(get_prop_morph_actions(
			target, initial, address.duplicate(), prop_name, do_edit_actions))


static func mk_object_for_class(class_string: String) -> Object:
	match class_string:
		'Greenhouse_PlantState':
			return Greenhouse_PlantState.new()
		'Greenhouse_Plant':
			return Greenhouse_Plant.new()
		'Greenhouse_LODVariant':
			return Greenhouse_LODVariant.new()
	return null


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


static func get_prop_morph_actions(t_val, i_val, adrs:Array, prop:String, edit_beforehand:bool = false):
	var morph_actions := []
	
	if !are_props_equal(t_val, i_val):
		if t_val is Array || t_val is Dictionary:
			t_val = t_val.duplicate()
		
		elif is_instance_of(t_val, Resource) && t_val.has_method("duplicate_ifr"):
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
		
		var morph_action_copy = morph_action.prop_action.duplicate(true)
		res.request_prop_action(morph_action_copy)





class MorphAction extends RefCounted:
	var prop_address:Array = []
	var prop_action:RefCounted = null
	
	
	func _init(_prop_address:Array = [], _prop_action:RefCounted = null):
		prop_address = _prop_address
		prop_action = _prop_action
	
	
	func _to_string():
		return "[%s:\n	%s]" % [str(prop_address), str(prop_action)]
