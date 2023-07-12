@tool
extends Node


const InputFieldResource = preload("res://addons/dreadpon.spatial_gardener/utility/input_field_resource/input_field_resource.gd")
const Greenhouse = preload("res://addons/dreadpon.spatial_gardener/greenhouse/greenhouse.gd")
const Toolshed = preload("res://addons/dreadpon.spatial_gardener/toolshed/toolshed.gd")
const PlantUtils = preload("plant_utils.gd")
const GenericUtils = preload("generic_utils.gd")
const Logger = preload("res://addons/dreadpon.spatial_gardener/utility/logger.gd")
const Globals = preload("res://addons/dreadpon.spatial_gardener/utility/globals.gd")
const FunLib = preload("res://addons/dreadpon.spatial_gardener/utility/fun_lib.gd")


@export var greenhouses:Array :set = set_greenhouses # (Array, Resource)
@export var toolsheds:Array : set = set_toolsheds # (Array, Resource)
@export var save_path:String = "" # (String, DIR)
@export var do_load_resources_for_edit:bool = false : set = set_do_load_resources_for_edit
@export var do_save_resources:bool = false : set = set_do_save_resources
@export var do_save_backups:bool = false : set = set_do_save_backups

var logger = null




func _init():
	greenhouses = []
	toolsheds = []
	logger = Logger.get_for(self)


func set_greenhouses(val):
	for i in range(0, val.size()):
		if val[i] == null:
			val[i] = Greenhouse.new()
	
	greenhouses = val


func set_toolsheds(val):
	for i in range(0, val.size()):
		if val[i] == null:
			val[i] = Toolshed.new()
	
	toolsheds = val


func set_do_load_resources_for_edit(val):
	do_load_resources_for_edit = false
	if val:
		load_resources_for_edit()


func set_do_save_resources(val):
	do_save_resources = false
	if val:
		save_resources()


func set_do_save_backups(val):
	do_save_backups = false
	if val:
		save_backups()


func load_resources_for_edit():
	greenhouses = _load_resources_for_edit("greenhouse")
	toolsheds = _load_resources_for_edit("toolshed")


func save_resources():
	for i in range(0, greenhouses.size()):
		if greenhouses.size() > 1:
			_save_resource(greenhouses[i], "greenhouse", i)
		else:
			_save_resource(greenhouses[i], "greenhouse", -1)
	
	for i in range(0, toolsheds.size()):
		if toolsheds.size() > 1:
			_save_resource(toolsheds[i], "toolshed", i)
		else:
			_save_resource(toolsheds[i], "toolshed", -1)


func save_backups():
	for i in range(0, greenhouses.size()):
		if greenhouses.size() > 1:
			_save_backup(greenhouses[i], "greenhouse", i)
		else:
			_save_backup(greenhouses[i], "greenhouse", -1)
	
	for i in range(0, toolsheds.size()):
		if toolsheds.size() > 1:
			_save_backup(toolsheds[i], "toolshed", i)
		else:
			_save_backup(toolsheds[i], "toolshed", -1)


func _save_resource(res:InputFieldResource, res_name:String, index:int = -1):
	res = res.duplicate_ifr(false, true)
	if index >= 0:
		FunLib.save_res(res, save_path, "%s_%d.tres" % [res_name, index])
	else:
		FunLib.save_res(res, save_path, "%s.tres" % [res_name])


func _save_backup(res:InputFieldResource, res_name:String, index:int = -1):
	res = res.duplicate_ifr(false, true)
	var full_path = ""
	var backup_path = ""
	var res_filename = ""
	
	if index >= 0:
		res_filename = "%s_%d.backup.tres" % [res_name, index]
		full_path = save_path + "/%s_%d.backup.tres" % [res_name, index]
		backup_path = save_path + "/%s_%d.backup" % [res_name, index]
	else:
		res_filename = "%s.backup.tres" % [res_name]
		full_path = save_path + "/%s.backup.tres" % [res_name]
		backup_path = save_path + "/%s.backup" % [res_name]
	
	FunLib.save_res(res, save_path, res_filename)
	var err = DirAccess.rename_absolute(full_path, backup_path)
	if err != OK:
		logger.error("Could not rename '%s' to '%s', error %s!" % [full_path, backup_path, Globals.get_err_message(err)])
	res.take_over_path(backup_path)


func _load_resources_for_edit(res_name:String) -> Array:
	var resources := []
	
	var i = 0
	var full_path = save_path + "/%s_%d.tres" % [res_name, i]
	while ResourceLoader.exists(full_path):
		resources.append(FunLib.load_res(save_path, "%s_%d.tres" % [res_name, i]))
		i += 1
		full_path = save_path + "/%s_%d.tres" % [res_name, i]
	
	return resources
