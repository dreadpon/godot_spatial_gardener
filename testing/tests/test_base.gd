@tool
extends Node


const GenericUtils = preload("../utility/generic_utils.gd")
const Logger = preload("res://addons/dreadpon.spatial_gardener/utility/logger.gd")
const FunLib = preload("res://addons/dreadpon.spatial_gardener/utility/fun_lib.gd")
const UndoRedoInterface = preload("res://addons/dreadpon.spatial_gardener/utility/undo_redo_interface.gd")

@export var do_execute:bool = false : set = set_do_execute
var logger = null
var undo_redo = null : set = dpon_testing_set_undo_redo
var is_executing:bool = false

signal finished_execution(result)
signal finished_undo_redo_action(current_action_index)




func _init():
	logger = Logger.get_for(self)
	dpon_testing_set_undo_redo(UndoRedo.new())


func set_do_execute(val):
	do_execute = false
	if val:
		if !is_executing:
			execute()


func execute():
	assert(!is_executing) # Trying to execute an already running test
	is_executing = true


func finish_execution(results:Array = []):
	is_executing = false
	finished_execution.emit(results)


func dpon_testing_set_undo_redo(val):
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
				action_name = "Undo: %s" % [UndoRedoInterface.get_current_action_name(undo_redo, self)]
				UndoRedoInterface.undo(undo_redo, self)
			else:
				current_action_index += 1
				action_name = "Redo: %s" % [UndoRedoInterface.get_current_action_name(undo_redo, self)]
				UndoRedoInterface.redo(undo_redo, self)
			callback_return_value = on_finished_undo_redo_action(current_action_index, action_name, callback_return_value, callback_binds)
	
	return callback_return_value


@warning_ignore("unused_parameter")
@warning_ignore("unused_parameter")
@warning_ignore("unused_parameter")
@warning_ignore("unused_parameter")
func on_finished_undo_redo_action(current_action_index:int, action_name:String, callback_return_value, callback_binds:Array = []):
	return null
