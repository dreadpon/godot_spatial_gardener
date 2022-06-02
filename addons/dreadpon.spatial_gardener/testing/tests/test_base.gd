tool
extends Node


const GenericUtils = preload("../utility/generic_utils.gd")
const Logger = preload("../../utility/logger.gd")
const FunLib = preload("../../utility/fun_lib.gd")


export var do_execute:bool = false setget set_do_execute
var logger = null
var undo_redo:UndoRedo = null setget set_undo_redo
var is_executing:bool = false

signal finished_execution(result)
signal finished_undo_redo_action(current_action_index)




func _init():
	logger = Logger.get_for(self)


func set_do_execute(val):
	do_execute = false
	if val:
		if !is_executing:
			execute()


func execute():
	assert(!is_executing, "Trying to execute an already running test!")
	is_executing = true


func finish_execution(results:Array = []):
	is_executing = false
	emit_signal("finished_execution", results)


func set_undo_redo(val):
	undo_redo = val


func print_and_get_result(list_index:int, error_counters:Dictionary):
	var results := []
	
	for counter_key in error_counters:
		var counter_val = error_counters[counter_key]
		
		var result = {"logger": logger, "severity": 0, "text": ""}
		result.severity = 2 if counter_val > 0 else 1
		result.text = GenericUtils.get_idx_msg("Test results:", list_index, "reported '%d' %s" % [counter_val, counter_key])
		results.append(result)
		
		match result.severity:
			0:
				logger.info(result.text)
			1:
				logger.info(result.text)
			2:
				logger.error(result.text)
	
	return results


func execute_undo_redo_sequence(intervals:Array, undoable_action_count:int, callback_binds:Array = []):
	var current_action_index := undoable_action_count
	var callback_return_value = null
	
	for index in intervals:
		while current_action_index != index:
			var action_name = ""
			if current_action_index > index:
				current_action_index -= 1
				action_name = "Undo: %s" % [undo_redo.get_current_action_name()]
				undo_redo.undo()
			else:
				current_action_index += 1
				action_name = "Redo: %s" % [undo_redo.get_current_action_name()]
				undo_redo.redo()
			callback_return_value = finished_undo_redo_action(current_action_index, action_name, callback_return_value, callback_binds)
	
	return callback_return_value


func finished_undo_redo_action(current_action_index:int, action_name:String, callback_return_value, callback_binds:Array = []):
	return null
