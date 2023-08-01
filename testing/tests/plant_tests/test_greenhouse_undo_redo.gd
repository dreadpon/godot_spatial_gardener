@tool
extends "test_plant_base.gd"



func execute():
	await get_tree().process_frame
	super.execute()
	
	var greenhouses := load_greenhouses()
	for greenhouse in greenhouses:
		greenhouse.set_undo_redo(undo_redo)
	
	var morphs_gone_wrong := 0
	var undo_redo_gone_wrong := 0
	logger.info("Executing test for '%d' greenhouses\n" % [greenhouses.size()])
	
	var curr_greenhouse:Greenhouse = greenhouses[0].duplicate_ifr(false, true)
	curr_greenhouse.set_undo_redo(undo_redo)
	for i in range(1, greenhouses.size()):
		var morph_actions = PlantUtils.get_morph_actions(greenhouses[i-1], greenhouses[i], false)
		var undoable_action_count = morph_actions.size()
		var morph_intervals := GenericUtils.get_action_intervals(undoable_action_count)
		
		PlantUtils.perform_morph_actions(curr_greenhouse, morph_actions)
		
		if find_discrepancies(-1, curr_greenhouse, greenhouses[i], "during morphing '%d'->'%d'" % [i - 1, i]):
			morphs_gone_wrong += 1
		
		undo_redo_gone_wrong += execute_undo_redo_sequence(
			morph_intervals, undoable_action_count,
			[greenhouses, i, curr_greenhouse, morph_actions])
	
	var results = print_and_get_result(-1, {"morph discrepancies": morphs_gone_wrong, "UndoRedo discrepancies": undo_redo_gone_wrong})
	finish_execution(results)
	if !Engine.is_editor_hint():
		UndoRedoInterface.clear_history(undo_redo)


func on_finished_undo_redo_action(current_action_index:int, action_name:String, callback_return_value, callback_binds:Array = []):
	var greenhouses = callback_binds[0]
	var greenhouse_i = callback_binds[1]
	var curr_greenhouse = callback_binds[2]
	var morph_actions = callback_binds[3]
	
	if callback_return_value == null:
		callback_return_value = 0
	
	# TODO: fix speed bottleneck below
	var interval_greenhouse = greenhouses[greenhouse_i-1].duplicate_ifr(false, true)
	interval_greenhouse.set_undo_redo(null)
	var interval_morph_actions = morph_actions.duplicate()
	interval_morph_actions.resize(current_action_index)
	# --- speed bottleneck passed ---
	
	PlantUtils.perform_morph_actions(interval_greenhouse, interval_morph_actions)
	
	if find_discrepancies(
		-1, curr_greenhouse, interval_greenhouse,
		"during '%s' '%d'->'%d' at interval '%d'" % [action_name, greenhouse_i - 1, greenhouse_i, current_action_index]):
		callback_return_value += 1
	
	return callback_return_value
