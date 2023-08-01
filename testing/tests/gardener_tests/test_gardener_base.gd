@tool
extends "../test_base.gd"


const GardenerUtils = preload("../../utility/gardener_utils.gd")
const GardenerScript = preload("../../utility/gardener_script.gd")
const OctreeIntegrityCheck = preload("../../checks/octree_integrity_check.gd")
const OctreeSnapshotCheck = preload("../../checks/octree_snapshot_check.gd")
const Greenhouse = preload("res://addons/dreadpon.spatial_gardener/greenhouse/greenhouse.gd")
const Gardener = preload("res://addons/dreadpon.spatial_gardener/gardener/gardener.gd")
const PainterAction = preload("../../utility/painter_action.gd")

const PropAction = preload("res://addons/dreadpon.spatial_gardener/utility/input_field_resource/prop_action.gd")
const PA_PropSet = preload("res://addons/dreadpon.spatial_gardener/utility/input_field_resource/pa_prop_set.gd")
const PA_PropEdit = preload("res://addons/dreadpon.spatial_gardener/utility/input_field_resource/pa_prop_edit.gd")
const PA_ArrayInsert = preload("res://addons/dreadpon.spatial_gardener/utility/input_field_resource/pa_array_insert.gd")
const PA_ArrayRemove = preload("res://addons/dreadpon.spatial_gardener/utility/input_field_resource/pa_array_remove.gd")
const PA_ArraySet = preload("res://addons/dreadpon.spatial_gardener/utility/input_field_resource/pa_array_set.gd")


@export var greenhouse_path:String = "" # (String, DIR)
var gardener:Gardener = null
var editor_selection:EditorSelection = null : set = dpon_testing_set_editor_selection

var painting_data:Array = []
var painter_script:Array = []
var stage:int = 0

# Any more difference should be concerning, but not necessary an error
# The density algorithm is an approximation after all
const max_member_count_difference:float = 0.333
const PRESET_COVERAGE_MODES_1COVER_4CENTER100 = [
	GardenerScript.CoverageMode.COVER, GardenerScript.CoverageMode.CENTER_100_PCT,
	GardenerScript.CoverageMode.CENTER_100_PCT, GardenerScript.CoverageMode.CENTER_100_PCT, GardenerScript.CoverageMode.CENTER_100_PCT]
const PRESET_COVERAGE_MODES_1COVER = [
	GardenerScript.CoverageMode.COVER]
const PRESET_COVERAGE_MODES_1_CLEAR = [
	GardenerScript.CoverageMode.CLEAR]
const PRESET_COVERAGE_MODES_5_CLEAR = [
	GardenerScript.CoverageMode.CLEAR, GardenerScript.CoverageMode.CLEAR, GardenerScript.CoverageMode.CLEAR,
	GardenerScript.CoverageMode.CLEAR, GardenerScript.CoverageMode.CLEAR]




func create_and_start_gardener_editing():
	FunLib.free_children(self)
	
	gardener = Gardener.new()
	add_child(gardener)
	
	editor_selection.clear()
	editor_selection.add_node(gardener)
	
	gardener.owner = get_tree().get_edited_scene_root()
	gardener.garden_work_directory = greenhouse_path
	gardener.gardening_collision_mask = pow(2, 0)
	
	for plant_state in gardener.greenhouse.greenhouse_plant_states:
		plant_state.request_prop_action(PA_PropSet.new("plant/plant_brush_active", true))
	select_brush(0)


func _enter_tree():
	FunLib.free_children(self)


func _exit_tree():
	FunLib.free_children(self)


func dpon_testing_set_editor_selection(val):
	editor_selection = val


func select_brush(index:int):
	var prop_action = PA_PropEdit.new("brush/active_brush", gardener.toolshed.brushes[index])
	gardener.toolshed.request_prop_action(prop_action)




func execute():
	super.execute()
	create_and_start_gardener_editing()
	gardener.forward_input_events = false
	stage = 0


func finish_execution(results:Array = []):
	if gardener:
		gardener.visible = false
		gardener.forward_input_events = true
	super.finish_execution(results)


func execute_next_stage():
	pass


func _process(delta):
	if !is_executing: return
	
	if !painter_script.is_empty():
		var painter_action = painter_script.pop_front()
		GardenerScript.execute_painter_action(gardener.painter, painter_action)
		finished_painter_action(painter_action)
	else:
		execute_next_stage()


func finished_painter_action(painter_action:PainterAction):
	pass


func print_and_get_result_indexed(error_counters_indexed:Dictionary) -> Array:
	var results := []
	for index in error_counters_indexed.keys():
		results.append_array(
			print_and_get_result(index, error_counters_indexed[index]))
	return results


func check_integrity() -> Dictionary:
	# This is needed to refresh all pending spawned spatials
	gardener.arborist.update_LODs()
	
	var error_counters_indexed := {}
	var coverage_modes_list:Array = get_coverage_modes_list()
	var check_results_bundle := OctreeIntegrityCheck.check_all_integrity(gardener, painting_data, coverage_modes_list)
	
	for i in range(0, check_results_bundle.results_list.size()):
		var check_results = check_results_bundle.results_list[i]
		error_counters_indexed[i] = {}
		process_check_results(i, check_results, error_counters_indexed[i])
	
	error_counters_indexed[-1] = {}
	process_check_results(-1, check_results_bundle.results, error_counters_indexed[-1])
	
	return error_counters_indexed


func process_check_results(index:int, check_results:Dictionary, error_counters:Dictionary):
	for key in check_results.keys():
		if check_results[key] is Array:
			var key_string = key.capitalize().to_lower()
			var results = check_results[key]
			
			if error_counters.has(key_string):
				error_counters[key_string] += results.size()
			else:
				error_counters[key_string] = results.size()
			
			logger.info(GenericUtils.get_idx_msg("", index, "found '%d' %s" % [results.size(), key_string]))
			
			for result_string in results:
				logger.info(GenericUtils.get_idx_msg("", index, "found %s %s" % [key_string, result_string]))
	
	if check_results.has("target_members"):
		var member_count_difference = max_member_count_difference * 2.0
		if check_results.target_members > 0:
			member_count_difference = abs(float(check_results.total_members) / check_results.target_members - 1.0)
		elif check_results.target_members <= 0 && check_results.total_members <= 0:
			member_count_difference = 0.0
		var too_big_member_difference = member_count_difference >= max_member_count_difference
		error_counters["member count difference"] = 1 if too_big_member_difference else 0
		logger.info(GenericUtils.get_idx_msg("", index,
			"found '%d' members, target: '%d' members, difference: '%f', max difference: '%f'" % [
				check_results.total_members, check_results.target_members, member_count_difference, max_member_count_difference]))


func get_coverage_modes_list():
	return []
