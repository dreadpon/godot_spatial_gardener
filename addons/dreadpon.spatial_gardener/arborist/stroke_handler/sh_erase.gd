tool
extends "stroke_handler.gd"


#-------------------------------------------------------------------------------
# Handle a regular erasing brush stroke
#-------------------------------------------------------------------------------

# Remove members from an octree according to the target density


func _init(_brush:Toolshed_Brush, _plant_states:Array, _octree_managers:Array, _space_state:PhysicsDirectSpaceState, _camera: Camera, _collision_mask:int).(
	_brush, _plant_states, _octree_managers, _space_state, _camera, _collision_mask):
		set_meta("class", "SH_Erase")


func volume_get_stroke_update_changes(brush_data:Dictionary, plant:Greenhouse_Plant, plant_index:int, octree_manager:MMIOctreeManager, 
	brush_placement_area:BrushPlacementArea, container_transform:Transform, painting_changes:PaintingChanges):
	
	# We create a grid and detect overlaps
	brush_placement_area.init_grid_data(plant.density_per_units, 1.0 - brush.behavior_strength)
#	brush_placement_area.max_placements_allowed *= 1.0 - brush.behavior_strength
	brush_placement_area.init_placement_overlaps(octree_manager)
	
	# We get overdense members - those that can't fit in a grid since their cells are already occupied
	# Then erase all of them
	brush_placement_area.invalidate_occupied_points()
	var members_for_deletion = brush_placement_area.get_members_for_deletion()
	for member_for_deletion in members_for_deletion:
		var octree_node = octree_manager.root_octree_node.find_child_by_address(member_for_deletion.node_address)
		var placement_transform = octree_node.members[member_for_deletion.member_index]
		
		painting_changes.add_change(PaintingChanges.ChangeType.ERASE, plant_index, placement_transform, placement_transform)


# No brush strength - no member filtering needed
# Just make changes with ALL overlapped points
func proj_get_stroke_update_changes(members_in_brush: Array, plant:Greenhouse_Plant, plant_index: int, octree_manager:MMIOctreeManager, painting_changes:PaintingChanges):
	for member_data in members_in_brush:
		painting_changes.add_change(PaintingChanges.ChangeType.ERASE, plant_index, member_data.member, member_data.member)
