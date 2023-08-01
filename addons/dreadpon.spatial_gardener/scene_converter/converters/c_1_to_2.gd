extends 'base_ver_converter.gd'


const Placeform = preload('../../arborist/placeform.gd')





func convert_gardener(parsed_scene: Array, run_mode: int, ext_res: Dictionary, sub_res: Dictionary):
	
	var to_erase = []
	
	for section in ext_res.values():
		if section.header.path.ends_with('dreadpon.spatial_gardener/arborist/placement_transform.gd'):
			to_erase.append(section)
	
	var total_sections = float(parsed_scene.size())
	var progress_milestone = 0
	var section_num = 0
	var found_octree_nodes = 0
	var found_placement_transforms = 0
	for section in parsed_scene:
		
		section_num += 1
		var file_progress = floor(section_num / total_sections * 100)
		if file_progress >= progress_milestone * 10:
			logger.info('Iterating sections: %02d%%' % [progress_milestone * 10])
			progress_milestone += 1
		
		if section.props.get('__meta__', {}).get('class', '') == 'Gardener':
			section.props['storage_version'] = 2
			continue
		
		if section.props.get('__meta__', {}).get('class', '') != 'MMIOctreeNode': continue
		found_octree_nodes += 1
		
		section.props.member_origin_offsets = Types.PropStruct.new('PoolRealArray( ')
		section.props.member_surface_normals = Types.PropStruct.new('PoolVector3Array( ')
		section.props.member_octants = Types.PropStruct.new('PoolByteArray( ')
		
		found_placement_transforms += section.props.members.size()
		for member_ref in section.props.members:
			var placeform_section = sub_res[member_ref.id]
			to_erase.append(placeform_section)
			
			var placeform := Placeform.mk(
				placeform_section.props.placement.variant(),
				placeform_section.props.surface_normal.variant(),
				placeform_section.props.transform.variant(),
				placeform_section.props.octree_octant
			)
			section.props.member_origin_offsets.content += Types.get_val_for_export(Placeform.get_origin_offset(placeform)) + ', '
			section.props.member_surface_normals.content += '%s, %s, %s, ' % [placeform[1][0], placeform[1][1], placeform[1][2]]
			section.props.member_octants.content += Types.get_val_for_export(placeform[3]) + ', '
		section.props.member_origin_offsets.content = section.props.member_origin_offsets.content.trim_suffix(', ') + ' )'
		section.props.member_surface_normals.content = section.props.member_surface_normals.content.trim_suffix(', ') + ' )'
		section.props.member_octants.content = section.props.member_octants.content.trim_suffix(', ') + ' )'
		section.props.erase('members')
	
	logger.info('Found OctreeNode objects: %d' % [found_octree_nodes])
	logger.info('Found PlacementTransform objects: %d' % [found_placement_transforms])
	
	for section in to_erase:
		parsed_scene.erase(section)
		var res_id = section.get('header', {}).get('id', -1)
		if res_id >= 0:
			sub_res.erase(res_id)
			ext_res.erase(res_id)
