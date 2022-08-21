tool
extends "stroke_handler.gd"


#-------------------------------------------------------------------------------
# Handle a reapply transforms brush stroke
#-------------------------------------------------------------------------------

# Get overlapping placements and generate a new Transform for each of them


# We keep references to placements we already reapplied as to not continously regenerate them
var reapplied_octree_members:Array




func _init(_brush:Toolshed_Brush, _plant_states:Array, _octree_managers:Array, _space_state:PhysicsDirectSpaceState, _camera: Camera, _collision_mask:int).(
	_brush, _plant_states, _octree_managers, _space_state, _camera, _collision_mask):
	
	set_meta("class", "SH_Reapply")
	reapplied_octree_members = []


func volume_get_stroke_update_changes(brush_data:Dictionary, plant:Greenhouse_Plant, plant_index:int, octree_manager:MMIOctreeManager, 
	brush_placement_area:BrushPlacementArea, container_transform:Transform, painting_changes:PaintingChanges):
	
	# We detect overlaps first
	brush_placement_area.init_placement_overlaps(octree_manager)
	# For each overlap we generate a new Transform and add it to the PaintingChange
	create_painting_changes(brush_placement_area.overlapped_octree_members, plant, plant_index, octree_manager, painting_changes)
	
#	# For each overlap we generate a new Transform and add it to the PaintingChange
#	for overlapped_member_data in brush_placement_area.overlapped_octree_members:
#		var octree_node = octree_manager.root_octree_node.find_child_by_address(overlapped_member_data.node_address)
#		var placement_transform = octree_node.members[overlapped_member_data.member_index]
#
#		# We use Vector3.to_string() to generate our reference keys
#		# I assume it's fully deterministic at least in the scope of an individual OS
#		var octree_member_key = str(placement_transform.placement)
#		if reapplied_octree_members.has(octree_member_key): continue
#		reapplied_octree_members.append(octree_member_key)
#
#		var plant_transform := TransformGenerator.generate_plant_transform(placement_transform.placement, placement_transform.surface_normal, plant, randomizer)
#		var new_placement_transform := PlacementTransform.new(placement_transform.placement, placement_transform.surface_normal, plant_transform, placement_transform.octree_octant)
#
#		# Painting changes here are non-standart: they actually have an octree node address and member index bundled
#		# We can't reliably use an address when adding/removing members since the octree might grow/collapse
#		# But here it's fine since we don't change the amount of members
#		painting_changes.add_change(PaintingChanges.ChangeType.SET, plant_index,
#			{"member": new_placement_transform, "index": overlapped_member_data.member_index, "address": overlapped_member_data.node_address},
#			{"member": placement_transform, "index": overlapped_member_data.member_index, "address": overlapped_member_data.node_address})


func proj_get_stroke_update_changes(members_in_brush: Array, plant:Greenhouse_Plant, plant_index: int, octree_manager:MMIOctreeManager, painting_changes:PaintingChanges):
	create_painting_changes(members_in_brush, plant, plant_index, octree_manager, painting_changes)


func create_painting_changes(member_data_array: Array, plant:Greenhouse_Plant, plant_index: int, octree_manager:MMIOctreeManager, painting_changes:PaintingChanges):
	for member_data in member_data_array:
		var octree_node = octree_manager.root_octree_node.find_child_by_address(member_data.node_address)
		var placement_transform = octree_node.members[member_data.member_index]
		
		# We use Vector3.to_string() to generate our reference keys
		# I assume it's fully deterministic at least in the scope of an individual OS
		var octree_member_key = str(placement_transform.placement)
		if reapplied_octree_members.has(octree_member_key): continue
		reapplied_octree_members.append(octree_member_key)
		
		var plant_transform := TransformGenerator.generate_plant_transform(placement_transform.placement, placement_transform.surface_normal, plant, randomizer)
		var new_placement_transform := PlacementTransform.new(placement_transform.placement, placement_transform.surface_normal, plant_transform, placement_transform.octree_octant)
		
		# Painting changes here are non-standart: they actually have an octree node address and member index bundled
		# We can't reliably use an address when adding/removing members since the octree might grow/collapse
		# But here it's fine since we don't change the amount of members
		painting_changes.add_change(PaintingChanges.ChangeType.SET, plant_index,
			{"member": new_placement_transform, "index": member_data.member_index, "address": member_data.node_address},
			{"member": placement_transform, "index": member_data.member_index, "address": member_data.node_address})
