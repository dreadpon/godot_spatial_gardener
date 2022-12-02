@tool
extends Node
class_name GreenhouseSaveLoadNode

var greenhouse:Greenhouse = null




func load_from_path(dir:String, res_name:String):
	greenhouse = FunLib.load_res(dir, res_name)


func save_current(dir:String, res_name:String):
	FunLib.save_res(greenhouse, dir, res_name)


func save_given(res:Greenhouse, dir:String, res_name:String):
	FunLib.save_res(res, dir, res_name)
	
