tool


const GenericUtils = preload("../utility/generic_utils.gd")
const GardenerUtils = preload("../utility/gardener_utils.gd")
const GardenerScript = preload("../utility/gardener_script.gd")
const OctreeManager = preload("../../arborist/mmi_octree/mmi_octree_manager.gd")
const OctreeNode = preload("../../arborist/mmi_octree/mmi_octree_node.gd")
const Greenhouse = preload("../../greenhouse/greenhouse.gd")
const Greenhouse_LODVariant = preload("../../greenhouse/greenhouse_LOD_variant.gd")
const Toolshed = preload("../../toolshed/toolshed.gd")
const Gardener = preload("../../gardener/gardener.gd")




static func check_all_integrity(gardener:Gardener, painting_data:Array, coverage_modes_list:Array) -> Dictionary:
	var total_results := {"results_list": [], "results": {"extra_MMIs": []}}
	for octree_index in range(0, gardener.arborist.octree_managers.size()):
		var results = check_integrity(gardener, octree_index, painting_data, coverage_modes_list[octree_index])
		total_results.results_list.append(results)
	
	for MMI in gardener.arborist.MMI_container.get_children():
		var found_MMI := false
		for results in total_results.results_list:
			if results.accounted_MMIs.has(MMI):
				found_MMI = true
				break
		if !found_MMI:
			total_results.results.extra_MMIs.append(
				MMI)
	
	for results in total_results.results_list:
		results.erase("accounted_MMIs")
	
	return total_results


static func check_integrity(gardener:Gardener, octree_index:int, painting_data:Array, coverage_modes:Array) -> Dictionary:
	var plant = gardener.greenhouse.greenhouse_plant_states[octree_index].plant
	var root_octree_node:OctreeNode = gardener.arborist.octree_managers[octree_index].root_octree_node
	var spawns_spatial:bool = plant.mesh_LOD_variants[0].spawned_spatial != null
	
	var plant_density:float = gardener.greenhouse.greenhouse_plant_states[octree_index].plant.density_per_units
	var brush_strength:float = gardener.toolshed.brushes[0].behavior_strength
	var target_members := GardenerScript.get_member_count_for_painting_data(painting_data, plant_density, brush_strength, coverage_modes)
	
	var structure_results := analyze_octree_node_structure(root_octree_node)
	var scene_tree_results := analyze_octree_scene_tree(root_octree_node, gardener.arborist.MMI_container, spawns_spatial)
	var total_results := combine_results(structure_results, scene_tree_results)
	total_results.target_members = target_members
	
	return total_results


static func analyze_octree_node_structure(octree_node:OctreeNode) -> Dictionary:
	var occupied_child_nodes := 0
	var node_results := {}
	node_results.can_fit_children_members = []
	node_results.has_only_one_child = []
	node_results.has_members_above_limit = []
	node_results.total_members = 0
	
	if octree_node.child_nodes.size() > 0:
		for child_node in octree_node.child_nodes:
			var child_node_results = analyze_octree_node_structure(child_node)
			append_results(node_results, child_node_results)
			if child_node.member_count() > 0 || child_node.child_nodes.size() > 0:
				occupied_child_nodes += 1
	else:
		node_results.total_members += octree_node.member_count()
	
	if octree_node.child_nodes.size() > 0:
		if node_results.total_members <= octree_node.max_members:
			node_results.total_members.append(
				"at %s" % [str(octree_node.get_address())])
		
		# To fulfill this check, we need all parent nodes to have only one occupied child too
		# All the way to the top
		if occupied_child_nodes == 1:
			node_results.has_only_one_child.append(
				"at %s" % [str(octree_node.get_address())])
		# If current node doesn't fulfill this requirement - clear the list
		else:
			node_results.has_only_one_child = []
	else:
		if octree_node.extent >= octree_node.min_leaf_extent && octree_node.member_count() > octree_node.max_members:
			node_results.has_members_above_limit.append(
				"at %s" % [str(octree_node.get_address())])
	
	return node_results


static func analyze_octree_scene_tree(octree_node:OctreeNode, MMI_container:Spatial, spawns_spatial:bool) -> Dictionary:
	var node_results := {}
	node_results.missing_MMIs = []
	node_results.extra_MMIs = []
	node_results.misnamed_MMIs = []
	node_results.node_missing_spawned_spatials = []
	node_results.node_with_extra_spawned_spatials = []
	node_results.accounted_MMIs = []
	
	if octree_node.child_nodes.size() > 0:
		for child_node in octree_node.child_nodes:
			var child_node_results = analyze_octree_scene_tree(child_node, MMI_container, spawns_spatial)
			append_results(node_results, child_node_results)
	else:
		if octree_node.MMI_name != octree_node.MMI.name:
			node_results.misnamed_MMIs.append(
				"at %s, %s != %s" % [str(octree_node.get_address()), octree_node.MMI_name, str(octree_node.MMI)])
		elif !MMI_container.get_children().has(octree_node.MMI):
			node_results.missing_MMIs.append(
				"at %s, %s" % [str(octree_node.get_address()), str(octree_node.MMI)])
		else:
			node_results.accounted_MMIs.append(octree_node.MMI)
			if spawns_spatial:
				if octree_node.MMI.get_children().size() < octree_node.member_count():
					node_results.node_missing_spawned_spatials.append(
						"at %s, from %s, %d are missing" % [str(octree_node.get_address()), octree_node.MMI, octree_node.member_count() - octree_node.MMI.get_children().size()])
				elif octree_node.MMI.get_children().size() > octree_node.member_count():
					node_results.node_missing_spawned_spatials.append(
						"at %s, from %s, %d are extra" % [str(octree_node.get_address()), octree_node.MMI, octree_node.MMI.get_children().size() - octree_node.member_count()])
	
	return node_results


static func append_results(target:Dictionary, source:Dictionary):
	for key in target.keys():
		if target[key] is Array:
			target[key].append_array(source[key])
		else:
			target[key] += source[key]


static func combine_results(one:Dictionary, two:Dictionary) -> Dictionary:
	var results := {}
	for key in one.keys():
		results[key] = one[key]
	for key in two.keys():
		results[key] = two[key]
	return results


