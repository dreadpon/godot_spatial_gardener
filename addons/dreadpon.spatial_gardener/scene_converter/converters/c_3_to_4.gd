extends 'base_ver_converter.gd'


const Placeform = preload('../../arborist/placeform.gd')





func convert_gardener(parsed_scene: Array, run_mode: int, ext_res: Dictionary, sub_res: Dictionary):
	
	var to_erase = []
	
	#for section in ext_res.values():
		#if section.header.path.ends_with('dreadpon.spatial_gardener/arborist/placement_transform.gd'):
			#to_erase.append(section)
	
	var total_sections = float(parsed_scene.size())
	var progress_milestone = 0
	var section_num = 0
	var found_octree_nodes = 0
	#var found_placement_transforms = 0
	var found_multimeshes = 0
	var found_multimesh_instances = 0
	var found_refd_multimesh = 0
	
	#var gardener_paths := []
	var octree_nodes_by_gardener := {}
	var multimeshes_by_gardener := {}
	var temp_octree_nodes := [[]]
	
	var gardeners := []
	var manager_indexes := {}
	var arborist_placeholders := []
	var arborist_sections := []
	
	#var instance_names_and_multimeshes := {}
	#var instance_names_and_octree_nodes := {}
	# Gather objects
	for section_idx in range(0, parsed_scene.size()):
		var section = parsed_scene[section_idx]
		section_num += 1
		var file_progress = floor(section_num / total_sections * 100)
		if file_progress >= progress_milestone * 10:
			logger.info('Iterating sections: %02d%%' % [progress_milestone * 10])
			progress_milestone += 1
		
		if section.props.get('metadata/class') == 'Gardener':
			section.props['storage_version'] = 4
			gardeners.append(section)
			#var node_path: String = section.header.parent.path_join(section.header.name).trim_prefix("./")
			#gardener_paths.append(node_path)
			continue
		
		if section.props.get('metadata/class') == 'MMIOctreeNode': 
			found_octree_nodes += 1
			temp_octree_nodes[-1].append(section)
			continue
		
		if section.props.get('metadata/class') == 'MMIOctreeManager': 
			temp_octree_nodes.append([])
			manager_indexes[section.header.id] = section_idx
			continue
		
		if section.props.get('metadata/class') == 'Arborist': 
			octree_nodes_by_gardener[section.header.parent] = {}
			#print(section.props.octree_managers.size(), " ", temp_octree_nodes.size())
			for i in range(0, section.props.octree_managers.size()):
				for octree_node in temp_octree_nodes[i]:
					octree_nodes_by_gardener[section.header.parent][octree_node.props.MMI_name] = octree_node
			temp_octree_nodes = temp_octree_nodes.slice(section.props.octree_managers.size())
			
			if section.props.octree_managers.size() > 0:
				arborist_placeholders.append(manager_indexes[section.props.octree_managers[-1].id] + 1)
				arborist_sections.append(section.duplicate(true))
		
		if section.header.has("parent"):
			for gardener_path in octree_nodes_by_gardener:
				if section.header.parent.begins_with(gardener_path) || section.header.parent == gardener_path:
					to_erase.append(section)
					break
		
		#if section.header.has("type") && section.header.type == 'MultiMesh': 
			#found_multimeshes += 1
			#instance_names_and_multimeshes[section.header.id] = section
			#continue
		
		if section.header.has("type") && section.header.type == 'MultiMeshInstance3D': 
			for gardener_path in octree_nodes_by_gardener:
				if section.header.parent.begins_with(gardener_path):
					found_multimesh_instances += 1
					if section.props.has("multimesh"):
						if !multimeshes_by_gardener.has(gardener_path):
							multimeshes_by_gardener[gardener_path] = {}
						var multimesh_id = section.props.multimesh.id
						multimeshes_by_gardener[gardener_path][section.header.name] = sub_res[multimesh_id]
						to_erase.append(sub_res[multimesh_id])
					#if section.props.has("multimesh"):
						#var multimesh_id = section.props.multimesh.id
						#if instance_names_and_multimeshes.has(multimesh_id):
							#instance_names_and_multimeshes[section.header.name] = instance_names_and_multimeshes[multimesh_id]
							#instance_names_and_multimeshes.erase(multimesh_id)
					break
	#print(octree_nodes_by_gardener.keys())
	
	#var json = JSON.new()
	#print(json.stringify(octree_nodes_by_gardener, "	", true, true))
	#print(json.stringify(multimeshes_by_gardener, "	", true, true))
	
	
	for gardener_path in octree_nodes_by_gardener:
		if !multimeshes_by_gardener.has(gardener_path): continue
		for MMI_name in octree_nodes_by_gardener[gardener_path]:
			if !multimeshes_by_gardener[gardener_path].has(MMI_name): continue
			
			var octree_section = octree_nodes_by_gardener[gardener_path][MMI_name]
			var multimesh = multimeshes_by_gardener[gardener_path][MMI_name]
			
			if !multimesh.props.has("buffer") || str_to_var(multimesh.props.buffer.content).is_empty(): continue
			if !octree_section.props.has("member_origin_offsets") || str_to_var(octree_section.props.member_origin_offsets.content).is_empty(): continue
			if !octree_section.props.has("member_surface_normals") || str_to_var(octree_section.props.member_surface_normals.content).is_empty(): continue
			if !octree_section.props.has("member_octants") || str_to_var(octree_section.props.member_octants.content).is_empty(): continue
			
			var member_origin_offsets = str_to_var(octree_section.props.member_origin_offsets.content)
			var member_surface_normals = str_to_var(octree_section.props.member_surface_normals.content)
			var multimesh_buffer = str_to_var(multimesh.props.buffer.content)
			var member_octants = str_to_var(octree_section.props.member_octants.content)
			
			octree_section.props.member_placeforms = []
			octree_section.props.member_placeforms.resize(member_origin_offsets.size())
			for i in range(member_origin_offsets.size()):
				var transform = Transform3D(
					Vector3(multimesh_buffer[i * 12 + 0], multimesh_buffer[i * 12 + 4], multimesh_buffer[i * 12 + 8]),
					Vector3(multimesh_buffer[i * 12 + 1], multimesh_buffer[i * 12 + 5], multimesh_buffer[i * 12 + 9]),
					Vector3(multimesh_buffer[i * 12 + 2], multimesh_buffer[i * 12 + 6], multimesh_buffer[i * 12 + 10]),
					Vector3(multimesh_buffer[i * 12 + 3], multimesh_buffer[i * 12 + 7], multimesh_buffer[i * 12 + 11]),
					)
				var placeform = Placeform.mk(Vector3.ZERO, member_surface_normals[i], transform, member_octants[i])
				Placeform.set_placement_from_origin_offset(placeform, member_origin_offsets[i])
				octree_section.props.member_placeforms[i] = [
					Types.PS_Vector3.new(var_to_str(placeform[0])), 
					Types.PS_Vector3.new(var_to_str(placeform[1])), 
					Types.PS_Transform.new(var_to_str(placeform[2])), 
					placeform[3]
					]
			octree_section.props.erase("member_origin_offsets")
			octree_section.props.erase("member_surface_normals")
			octree_section.props.erase("member_octants")
			octree_section.props.erase("MMI_name")
			
			#var new_props := {}
			#var keys = octree_section.props.keys()
			#keys.sort()
			#for key in keys:
				#new_props[key] = octree_section.props[key]
			#
			#octree_section.props = new_props
			#print(octree_section.props.member_placeforms)
			
			#print("%s/%s: %s %s" % [gardener_path, MMI_name, str(octree_section), str(multimesh)])
		#return Transform3D(Vector3(split[0], split[3], split[6]), Vector3(split[1], split[4], split[7]), Vector3(split[2], split[5], split[8]), Vector3(split[9], split[10], split[11]))

	# Iterate instance_names_and_multimeshes
	# Find out which are referenced by Octree Nodes
	# to_erase add MultiMeshes that are references (not MMIs!)
	
	# Create member_placeforms array
	# Extract transform from MMI
	# Extract Packed Arrays from Node
	# Combine them
	# Initialize member_placeforms
		
		
		
		
		
		
		#section.props.member_origin_offsets = Types.PropStruct.new('PackedFloat32Array( ')
		#section.props.member_surface_normals = Types.PropStruct.new('PackedVector3Array( ')
		#section.props.member_octants = Types.PropStruct.new('PackedByteArray( ')
		#
		#found_placement_transforms += section.props.members.size()
		#for member_ref in section.props.members:
			#var placeform_section = sub_res[member_ref.id]
			#to_erase.append(placeform_section)
			#
			#var placeform := Placeform.mk(
				#placeform_section.props.placement.variant(),
				#placeform_section.props.surface_normal.variant(),
				#placeform_section.props.transform.variant(),
				#placeform_section.props.octree_octant
			#)
			#section.props.member_origin_offsets.content += Types.get_val_for_export(Placeform.get_origin_offset(placeform)) + ', '
			#section.props.member_surface_normals.content += '%s, %s, %s, ' % [placeform[1][0], placeform[1][1], placeform[1][2]]
			#section.props.member_octants.content += Types.get_val_for_export(placeform[3]) + ', '
		#section.props.member_origin_offsets.content = section.props.member_origin_offsets.content.trim_suffix(', ') + ' )'
		#section.props.member_surface_normals.content = section.props.member_surface_normals.content.trim_suffix(', ') + ' )'
		#section.props.member_octants.content = section.props.member_octants.content.trim_suffix(', ') + ' )'
		#section.props.erase('members')
	
	#print(gardener_paths)
	#for section in to_erase:
		#print(section)
	#for key in instance_names_and_multimeshes:
		#print(key, ": ", instance_names_and_multimeshes[key])
	
	logger.info('Found OctreeNode objects: %d' % [found_octree_nodes])
	logger.info('Found MultiMesh objects: %d' % [found_multimeshes])
	logger.info('Found MultiMeshInstance3D objects: %d' % [found_multimesh_instances])
	#logger.info('Found PlacementTransform objects: %d' % [found_placement_transforms])
	
	print(arborist_placeholders, " ", arborist_sections.size())
	for i in range(arborist_placeholders.size() - 1, -1, -1):
		var section_idx = arborist_placeholders[i]
		var section = arborist_sections[i]
		section.type = "sub_resource"
		section.header = {"type": "Resource", "id": "Resource_Arborist_%d" % [i]}
		parsed_scene.insert(section_idx, arborist_sections[i])
	
	for i in range(0, gardeners.size()):
		gardeners[i].props.arborist = Types.SubResource.new("Resource_Arborist_%d" % [i])
	
	for section in to_erase:
		parsed_scene.erase(section)
		var res_id = section.get('header', {}).get('id', "")
		if !res_id.is_empty():
			sub_res.erase(res_id)
			ext_res.erase(res_id)
