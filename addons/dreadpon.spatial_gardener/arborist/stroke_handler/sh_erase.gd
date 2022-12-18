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
	var placeforms_data_for_deletion = brush_placement_area.get_placeforms_for_deletion()
	for placeform_data_for_deletion in placeforms_data_for_deletion:
		var octree_node = octree_manager.root_octree_node.find_child_by_address(placeform_data_for_deletion.node_address)
		var placeform = octree_node.get_placeform(placeform_data_for_deletion.member_idx)
		
		painting_changes.add_change(PaintingChanges.ChangeType.ERASE, plant_index, placeform, placeform)


# No brush strength - no member filtering needed
# Just make changes with ALL overlapped points
func proj_get_stroke_update_changes(placeforms_data_in_brush: Array, plant:Greenhouse_Plant, plant_index: int, octree_manager:MMIOctreeManager, painting_changes:PaintingChanges):
	for placeform_data in placeforms_data_in_brush:
		painting_changes.add_change(PaintingChanges.ChangeType.ERASE, plant_index, placeform_data.placeform, placeform_data.placeform)
