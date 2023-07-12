@tool
extends Node


const FunLib = preload("res://addons/dreadpon.spatial_gardener/utility/fun_lib.gd")
const Greenhouse = preload("res://addons/dreadpon.spatial_gardener/greenhouse/greenhouse.gd")


var greenhouse:Greenhouse = null




func load_from_path(dir:String, res_name:String):
	greenhouse = FunLib.load_res(dir, res_name)


func save_current(dir:String, res_name:String):
	FunLib.save_res(greenhouse, dir, res_name)


func save_given(res:Greenhouse, dir:String, res_name:String):
	FunLib.save_res(res, dir, res_name)
	
