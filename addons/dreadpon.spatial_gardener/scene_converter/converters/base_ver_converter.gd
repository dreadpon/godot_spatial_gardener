extends Reference

enum RunMode {RECREATE, DRY, CONVERT}

const Types = preload('../converter_types.gd')
var Logger = preload('../../utility/logger.gd')

var logger




func _init():
	logger = Logger.get_for(self)


func convert_gardener(parsed_scene: Array, run_mode: int, ext_res: Dictionary, sub_res: Dictionary):
	pass
