@tool
extends TestGardenerBase




func execute():
	super.execute()
	logger.info("Executing test")
	painting_data = GardenerUtils.populate_node_with_surfaces(self, true, true)


func execute_next_stage():
	match stage:
		0:
			select_brush(0)
			painter_script = (
				Check_Gardener.mk_script(painting_data[0], Check_Gardener.CoverageMode.COVER, Vector2(5,30)) +
				Check_Gardener.mk_script(painting_data[1], Check_Gardener.CoverageMode.CENTER_100_PCT) +
				Check_Gardener.mk_script(painting_data[2], Check_Gardener.CoverageMode.CENTER_100_PCT) +
				Check_Gardener.mk_script(painting_data[3], Check_Gardener.CoverageMode.CENTER_100_PCT) +
				Check_Gardener.mk_script(painting_data[4], Check_Gardener.CoverageMode.CENTER_100_PCT))

		1:
			select_brush(1)
			painter_script = (
				Check_Gardener.mk_script(painting_data[0], Check_Gardener.CoverageMode.SPOTTY_50_PCT, Vector2(5,10)) +
				Check_Gardener.mk_script(painting_data[1], Check_Gardener.CoverageMode.CENTER_50_PCT) +
				Check_Gardener.mk_script(painting_data[2], Check_Gardener.CoverageMode.CENTER_50_PCT) +
				Check_Gardener.mk_script(painting_data[3], Check_Gardener.CoverageMode.CENTER_50_PCT) +
				Check_Gardener.mk_script(painting_data[4], Check_Gardener.CoverageMode.CENTER_50_PCT))

		2:
			select_brush(0)
			painter_script = (
				Check_Gardener.mk_script(painting_data[0], Check_Gardener.CoverageMode.COVER, Vector2(40,40)) +
				Check_Gardener.mk_script(painting_data[1], Check_Gardener.CoverageMode.CENTER_100_PCT) +
				Check_Gardener.mk_script(painting_data[2], Check_Gardener.CoverageMode.CENTER_100_PCT) +
				Check_Gardener.mk_script(painting_data[3], Check_Gardener.CoverageMode.CENTER_100_PCT) +
				Check_Gardener.mk_script(painting_data[4], Check_Gardener.CoverageMode.CENTER_100_PCT))
		
		3:
			var results = print_and_get_result_indexed(check_integrity())
			finish_execution(results)
			return
	
	stage += 1


func get_coverage_modes_list():
	var coverage_modes_list := []
	for octree_index in range(0, gardener.arborist.octree_managers.size()):
		if gardener.greenhouse.greenhouse_plant_states[octree_index].plant_brush_active:
			coverage_modes_list.append(PRESET_COVERAGE_MODES_1COVER_4CENTER100)
		else:
			coverage_modes_list.append(PRESET_COVERAGE_MODES_5_CLEAR)
	return coverage_modes_list
