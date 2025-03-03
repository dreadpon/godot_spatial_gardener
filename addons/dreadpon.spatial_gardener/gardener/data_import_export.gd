extends RefCounted

const Logger = preload("../utility/logger.gd")
const Globals = preload("../utility/globals.gd")
const FunLib = preload("../utility/fun_lib.gd")
const Defaults = preload("../utility/defaults.gd")
const Greenhouse = preload("../greenhouse/greenhouse.gd")
const Toolshed = preload("../toolshed/toolshed.gd")
const Painter = preload("painter.gd")
const Arborist = preload("../arborist/arborist.gd")
const Placeform = preload("../arborist/placeform.gd")
const InputFieldResource = preload("../utility/input_field_resource/input_field_resource.gd")

var logger = null
var arborist: Arborist = null
var greenhouse: Greenhouse = null
var toolshed: Toolshed = null




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(_arborist: Arborist, _greenhouse: Greenhouse, _toolshed: Toolshed = null):
	logger = Logger.get_for(self)
	arborist = _arborist
	greenhouse = _greenhouse
	toolshed = _toolshed




#-------------------------------------------------------------------------------
# Importing/exporting data
#-------------------------------------------------------------------------------


# Import data of a single plant (Greenhouse_Plant + placeforms)
func import_plant_data(file_path: String, plant_idx: int, replace_existing: bool):
	var file := FileAccess.open(file_path, FileAccess.READ)
	if !file:
		logger.error("Could not import '%s', error %s!" % [file_path, Globals.get_err_message(FileAccess.get_open_error())])
	
	var test_json_conv = JSON.new()
	var err = test_json_conv.parse(file.get_as_text())
	if err != OK:
		logger.error("Could not parse json at '%s', error %s!" % [file_path, Globals.get_err_message(err)])
		return
	
	var import_data = test_json_conv.data
	file.close()
	
	if replace_existing:
		greenhouse.remove_plant(plant_idx)
	_import_process_data(plant_idx, import_data, replace_existing)
	
	if import_data is Dictionary && !import_data.get("plant_data", {}).is_empty():
		logger.info("Successfully imported plant settings and placeform(s) from '%s'" % [file_path])
	else:
		logger.info("Successfully imported placeform(s) from '%s'" % [file_path])


# Export data of a single plant (Greenhouse_Plant + placeforms)
func export_plant_data(file_path: String, plant_idx: int):
	DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if !file:
		logger.error("Could not export '%s', error %s!" % [file_path, Globals.get_err_message(FileAccess.get_open_error())])
	
	var data = _export_gather_data(plant_idx)
	
	var json_string = JSON.stringify(data)
	file.store_string(json_string)
	file.close()
	logger.info("Successfully exported plant settings and placeform(s) to '%s'" % [file_path])




# Import data of an entire Greenhouse + placeforms
func import_greenhouse_data(file_path: String, replace_existing: bool):
	var file := FileAccess.open(file_path, FileAccess.READ)
	if !file:
		logger.error("Could not import '%s', error %s!" % [file_path, Globals.get_err_message(FileAccess.get_open_error())])
	
	var test_json_conv = JSON.new()
	var err = test_json_conv.parse(file.get_as_text())
	if err != OK:
		logger.error("Could not parse json at '%s', error %s!" % [file_path, Globals.get_err_message(err)])
		return
	
	var import_data = test_json_conv.data
	file.close()
	
	if replace_existing:
		for i in greenhouse.greenhouse_plant_states.size():
			greenhouse.remove_plant(0)
	for i in import_data.size():
		_import_process_data(i, import_data[i], replace_existing)
	
	logger.info("Successfully imported entire greenhouse of %d plants from '%s" % [import_data.size(), file_path])


# Export data of an entire Greenhouse + placeforms
func export_greenhouse_data(file_path: String):
	DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if !file:
		logger.error("Could not export '%s', error %s!" % [file_path, Globals.get_err_message(FileAccess.get_open_error())])
	
	var data = []
	for plant_idx in range(greenhouse.greenhouse_plant_states.size()):
		data.append(_export_gather_data(plant_idx))
	
	var json_string = JSON.stringify(data)
	file.store_string(json_string)
	file.close()
	logger.info("Successfully exported entire greenhouse of %d plants to '%s'" % [data.size(), file_path])




func _export_gather_data(plant_idx: int) -> Dictionary:
	var plant_data = greenhouse.greenhouse_plant_states[plant_idx].ifr_to_dict(true)
	var placeforms: Array = []
	arborist.octree_managers[plant_idx].get_all_placeforms(placeforms)
	var placeform_data := []
	for placeform in placeforms:
		placeform_data.append({
			'placement': FunLib.vec3_to_str(placeform[0]),
			'surface_normal': FunLib.vec3_to_str(placeform[1]),
			'transform': FunLib.transform3d_to_str(placeform[2]),
		})
	
	logger.info("Successfully gathered plant settings and %d placeform(s) at index %d" % [placeform_data.size(), plant_idx])
	
	return {
		plant_data = plant_data,
		placeform_data = placeform_data
	}


func _import_process_data(plant_idx: int, data, replace_existing: bool):
	var placeform_data := []
	var plant_data := {}
	# New version, plant settings + transforms
	if data is Dictionary:
		placeform_data = data.placeform_data
		plant_data = data.plant_data
	# Old version, supports transforms-only, for Spatial Gardener 1.2.0 compatability
	else:
		placeform_data = data
	
	var str_version = 1
	if !placeform_data.is_empty():
		var placeforms := []
		if placeform_data[0].transform.contains(" - "):
			str_version = 0
	
	if !plant_data.is_empty():
		plant_idx = greenhouse.add_plant_from_dict(plant_data, str_version)
	
	if !placeform_data.is_empty():
		var placeforms := []
		for placeform_dict in placeform_data:
			placeforms.append(Placeform.mk(
				FunLib.str_to_vec3(placeform_dict.placement, str_version), 
				FunLib.str_to_vec3(placeform_dict.surface_normal, str_version), 
				FunLib.str_to_transform3d(placeform_dict.transform, str_version)))
		
		arborist.batch_add_instances(placeforms, plant_idx)
		arborist.call_deferred("emit_member_count", plant_idx)
