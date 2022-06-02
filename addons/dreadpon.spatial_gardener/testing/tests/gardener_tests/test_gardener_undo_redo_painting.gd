tool
extends "test_gardener_base.gd"


var octree_snapshot_check:OctreeSnapshotCheck = null
var painter_scripts:Array
var undoable_action_count:int = 0
var action_intervals:Array

# Tree comparison doesn't make sense because of Godot autonaming nodes
# When we undo and then redo, we do not enforce previous names, so Godot decides the name on it's own
# Which is expected behavior and thus perfectly fine

# Neither does octree comparison
# Octree structure can be predicted of course, but making sure they behave the same way after a dozen of undos, redos or regenerations
# Is just not worth it ¯\_(ツ)_/¯

var member_count_snapshots_list:Array = []




func execute():
	.execute()
	logger.info("Executing test")
	octree_snapshot_check = OctreeSnapshotCheck.new()
	painting_data = GardenerUtils.populate_node_with_surfaces(self, true, false)
	
	painter_scripts = [
		GardenerScript.mk_script(painting_data[0], GardenerScript.CoverageMode.COVER, Vector2(20,20), GardenerScript.PRESET_STROKE_LENGTH_JITTER),
		GardenerScript.mk_script(painting_data[0], GardenerScript.CoverageMode.SPOTTY_75_PCT, Vector2(10,10), GardenerScript.PRESET_STROKE_LENGTH_JITTER),
		GardenerScript.mk_script(painting_data[0], GardenerScript.CoverageMode.COVER, Vector2(20,20), GardenerScript.PRESET_STROKE_LENGTH_JITTER)
	]
	
	undoable_action_count = 0
	for script in painter_scripts:
		for painter_action in script:
			if painter_action.action_type == PainterAction.PainterActionType.END_STROKE:
				undoable_action_count += 1
	action_intervals = GenericUtils.get_action_intervals(undoable_action_count)
	
	member_count_snapshots_list = []


func execute_next_stage():
	match stage:
		0:
			select_brush(0)
			painter_script = painter_scripts[0]
		
		1:
			select_brush(1)
			painter_script = painter_scripts[1]

		2:
			select_brush(0)
			painter_script = painter_scripts[2]
		
		3:
			var undo_redo_gone_wrongs = execute_undo_redo_sequence(
				action_intervals, undoable_action_count, [])
			
			var results = print_and_get_result_indexed(check_integrity())
			results.append_array(print_and_get_result_indexed(undo_redo_gone_wrongs))
			
			finish_execution(results)
			return
	
	stage += 1


func finished_painter_action(painter_action:PainterAction):
	if painter_action.action_type != PainterAction.PainterActionType.END_STROKE: return
	
	for i in range(0, gardener.arborist.octree_managers.size()):
		var root_octree_node = gardener.arborist.octree_managers[i].root_octree_node
		if member_count_snapshots_list.size() <= i:
			member_count_snapshots_list.append([0])
		member_count_snapshots_list[i].append(root_octree_node.get_all_members().size())


func finished_undo_redo_action(current_action_index:int, action_name:String, callback_return_value, callback_binds:Array = []):
	if callback_return_value == null:
		callback_return_value = {}
	
	for i in range(0, gardener.arborist.octree_managers.size()):
		if callback_return_value.size() <= i:
			callback_return_value[i] = {"member count snapshot discrepancy": 0}
		
		var root_octree_node = gardener.arborist.octree_managers[i].root_octree_node
		var member_count_snapshots = member_count_snapshots_list[i]
		
		var given_total_members = root_octree_node.get_all_members().size()
		var reference_total_members = member_count_snapshots[current_action_index]
		var check_text = "during '%s' at interval '%d'" % [action_name, current_action_index]
		
		if given_total_members != reference_total_members:
			callback_return_value[i]["member count snapshot discrepancy"] += 1
			logger.info("Member count not equal in 'given' to 'reference' ('%d' != '%d') %s" % [given_total_members, reference_total_members, check_text])
			logger.info(GardenerUtils.snapshot_octrees(gardener.arborist.octree_managers))
	
	return callback_return_value


func get_coverage_modes_list():
	var coverage_modes_list := []
	for octree_index in range(0, gardener.arborist.octree_managers.size()):
		if gardener.greenhouse.greenhouse_plant_states[octree_index].plant_brush_active:
			coverage_modes_list.append(PRESET_COVERAGE_MODES_1COVER)
		else:
			coverage_modes_list.append(PRESET_COVERAGE_MODES_1_CLEAR)
	return coverage_modes_list
