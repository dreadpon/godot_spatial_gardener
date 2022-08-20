tool
extends "test_gardener_base.gd"


var octree_snapshot_check:OctreeSnapshotCheck = null




func execute():
	.execute()
	logger.info("Executing test")
	octree_snapshot_check = OctreeSnapshotCheck.new()
	painting_data = GardenerUtils.populate_node_with_surfaces(self, true, true)


func execute_next_stage():
	match stage:
		0:
			select_brush(0)
			painter_script = (
				GardenerScript.mk_script(painting_data[0], GardenerScript.CoverageMode.COVER, Vector2(40,40)) +
				GardenerScript.mk_script(painting_data[1], GardenerScript.CoverageMode.CENTER_100_PCT) +
				GardenerScript.mk_script(painting_data[2], GardenerScript.CoverageMode.CENTER_100_PCT) +
				GardenerScript.mk_script(painting_data[3], GardenerScript.CoverageMode.CENTER_100_PCT) +
				GardenerScript.mk_script(painting_data[4], GardenerScript.CoverageMode.CENTER_100_PCT))
		
		1:
			select_brush(1)
			painter_script = (
				GardenerScript.mk_script(painting_data[0], GardenerScript.CoverageMode.SPOTTY_50_PCT, Vector2(5,20)) +
				GardenerScript.mk_script(painting_data[1], GardenerScript.CoverageMode.CENTER_50_PCT) +
				GardenerScript.mk_script(painting_data[2], GardenerScript.CoverageMode.CENTER_50_PCT) +
				GardenerScript.mk_script(painting_data[3], GardenerScript.CoverageMode.CENTER_50_PCT) +
				GardenerScript.mk_script(painting_data[4], GardenerScript.CoverageMode.CENTER_50_PCT))
		
		2:
			octree_snapshot_check.snapshot_tree(gardener.arborist.MMI_container)
			octree_snapshot_check.snapshot_octrees(gardener.arborist.octree_managers)
			save_gardener()
		
		3:
			load_gardener()
			octree_snapshot_check.snapshot_tree(gardener.arborist.MMI_container)
			octree_snapshot_check.snapshot_octrees(gardener.arborist.octree_managers)
		
		4:
			select_brush(0)
			painter_script = (
				GardenerScript.mk_script(painting_data[0], GardenerScript.CoverageMode.COVER, Vector2(40,40)) +
				GardenerScript.mk_script(painting_data[1], GardenerScript.CoverageMode.CENTER_100_PCT) +
				GardenerScript.mk_script(painting_data[2], GardenerScript.CoverageMode.CENTER_100_PCT) +
				GardenerScript.mk_script(painting_data[3], GardenerScript.CoverageMode.CENTER_100_PCT) +
				GardenerScript.mk_script(painting_data[4], GardenerScript.CoverageMode.CENTER_100_PCT))
		
		5:
			var tree_discrepancies = octree_snapshot_check.check_tree_snapshots(logger)
			var octree_discrepancies = octree_snapshot_check.check_octree_snapshots(logger)
			var results = print_and_get_result_indexed(check_integrity())
			results.append_array(print_and_get_result(-1, {
				"node tree discrepancies": tree_discrepancies.size(),
				"octree discrepancies": octree_discrepancies.size()}))
			
			finish_execution(results)
			return
	
	stage += 1




func save_gardener():
	reassign_gardener_tree_owner(gardener.arborist, gardener)
	var packed_scene = PackedScene.new()
	packed_scene.pack(gardener)
	FunLib.save_res(packed_scene, greenhouse_path, "gardener.tscn")
	remove_child(gardener)
	editor_selection.clear()


func load_gardener():
	var packed_scene = FunLib.load_res(greenhouse_path, "gardener.tscn")
	gardener = packed_scene.instance()
	add_child(gardener)
	gardener.owner = get_tree().get_edited_scene_root()
	editor_selection.clear()
	editor_selection.add_node(gardener)


func reassign_gardener_tree_owner(node:Node, new_owner:Node):
	node.owner = new_owner
	for child in node.get_children():
		reassign_gardener_tree_owner(child, new_owner)


func get_coverage_modes_list():
	var coverage_modes_list := []
	for octree_index in range(0, gardener.arborist.octree_managers.size()):
		if gardener.greenhouse.greenhouse_plant_states[octree_index].plant_brush_active:
			coverage_modes_list.append(PRESET_COVERAGE_MODES_1COVER_4CENTER100)
		else:
			coverage_modes_list.append(PRESET_COVERAGE_MODES_5_CLEAR)
	return coverage_modes_list
