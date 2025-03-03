@tool


const GenericUtils = preload("../utility/generic_utils.gd")
const GardenerUtils = preload("../utility/gardener_utils.gd")
const GardenerScript = preload("../utility/gardener_script.gd")
const OctreeManager = preload("res://addons/dreadpon.spatial_gardener/arborist/mmi_octree/mmi_octree_manager.gd")
const OctreeNode = preload("res://addons/dreadpon.spatial_gardener/arborist/mmi_octree/mmi_octree_node.gd")
const Greenhouse = preload("res://addons/dreadpon.spatial_gardener/greenhouse/greenhouse.gd")
const Greenhouse_LODVariant = preload("res://addons/dreadpon.spatial_gardener/greenhouse/greenhouse_LOD_variant.gd")
const Toolshed = preload("res://addons/dreadpon.spatial_gardener/toolshed/toolshed.gd")
const Gardener = preload("res://addons/dreadpon.spatial_gardener/gardener/gardener.gd")




static func check_all_integrity(gardener:Gardener, painting_data:Array, coverage_modes_list:Array) -> Dictionary:
	var total_results := {"results_list": [], "results": {"extra_multimeshes": []}}
	for octree_index in range(0, gardener.arborist.octree_managers.size()):
		var results = check_integrity(gardener, octree_index, painting_data, coverage_modes_list[octree_index])
		total_results.results_list.append(results)
	
	return total_results


static func check_integrity(gardener:Gardener, octree_index:int, painting_data:Array, coverage_modes:Array) -> Dictionary:
	var plant = gardener.greenhouse.greenhouse_plant_states[octree_index].plant
	var root_octree_node:OctreeNode = gardener.arborist.octree_managers[octree_index].root_octree_node
	var spawns_mesh:bool = plant.mesh_LOD_variants[0].mesh != null
	var spawns_spatial:bool = plant.mesh_LOD_variants[0].spawned_spatial != null
	
	var plant_density:float = gardener.greenhouse.greenhouse_plant_states[octree_index].plant.density_per_units
	var brush_strength:float = gardener.toolshed.brushes[0].behavior_strength
	var target_members := GardenerScript.get_member_count_for_painting_data(painting_data, plant_density, brush_strength, coverage_modes)
	
	var structure_results := analyze_octree_node_structure(root_octree_node)
	var scene_tree_results := analyze_octree_scene_tree(root_octree_node, gardener, spawns_mesh, spawns_spatial)
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
			if child_node.get_member_count() > 0 || child_node.child_nodes.size() > 0:
				occupied_child_nodes += 1
	else:
		node_results.total_members += octree_node.get_member_count()
	
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
		if octree_node.extent >= octree_node.min_leaf_extent && octree_node.get_member_count() > octree_node.max_members:
			node_results.has_members_above_limit.append(
				"at %s" % [str(octree_node.get_address())])
	
	return node_results


static func analyze_octree_scene_tree(octree_node:OctreeNode, gardener_root:Node3D, spawns_mesh:bool, spawns_spatial:bool) -> Dictionary:
	var node_results := {}
	node_results.missing_multimeshes = []
	node_results.extra_multimeshes = []
	#node_results.misnamed_multimeshes = []
	node_results.node_missing_spawned_spatials = []
	node_results.node_with_extra_spawned_spatials = []
	#node_results.accounted_multimeshes = []
	
	if octree_node.child_nodes.size() > 0:
		for child_node in octree_node.child_nodes:
			var child_node_results = analyze_octree_scene_tree(child_node, gardener_root, spawns_mesh, spawns_spatial)
			append_results(node_results, child_node_results)
	else:
		if spawns_mesh:
			if octree_node.get_member_count() > 0 && (!octree_node.leaf._RID_multimesh.is_valid() || RenderingServer.multimesh_get_instance_count(octree_node.leaf._RID_multimesh) != octree_node.get_member_count()):
				node_results.missing_multimeshes.append(
					"at %s, %s" % [str(octree_node.get_address()), str(octree_node.leaf._RID_multimesh)])
			elif octree_node.leaf._RID_multimesh.is_valid() && (octree_node.get_member_count() <= 0 || !octree_node.is_leaf):
				node_results.extra_multimeshes.append(
					"at %s, %s" % [str(octree_node.get_address()), str(octree_node.leaf._RID_multimesh)])
		else:
			#node_results.accounted_multimeshes.append(octree_node.leaf._RID_multimesh)
			if spawns_spatial:
				if octree_node.leaf._spawned_spatial_container.get_children(true).size() < octree_node.get_member_count():
					node_results.node_missing_spawned_spatials.append(
						"at %s, from %s, %d are missing" % [str(octree_node.get_address()), octree_node.leaf._RID_multimesh, octree_node.get_member_count() - octree_node.leaf._spawned_spatial_container.get_children(true).size()])
				elif octree_node.leaf._spawned_spatial_container.get_children().size() > octree_node.get_member_count():
					node_results.node_missing_spawned_spatials.append(
						"at %s, from %s, %d are extra" % [str(octree_node.get_address()), octree_node.leaf._RID_multimesh, octree_node.leaf._spawned_spatial_container.get_children(true).size() - octree_node.get_member_count()])
	
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
