tool
extends "stroke_handler.gd"


#-------------------------------------------------------------------------------
# Handle a regular painting brush stroke
#-------------------------------------------------------------------------------

# Add members to an octree according to the target density


func _init(_brush:Toolshed_Brush, _plant_states:Array, _octree_managers:Array, _space_state:PhysicsDirectSpaceState, _camera: Camera, _collision_mask:int).(
	_brush, _plant_states, _octree_managers, _space_state, _camera, _collision_mask):
	
	set_meta("class", "SH_Paint")


func should_abort_early(brush_data:Dictionary):
	if brush.behavior_overlap_mode == Toolshed_Brush.OverlapMode.PROJECTION: return true
	if brush.behavior_strength <= 0.0: return true
	return false


func volume_get_stroke_update_changes(brush_data:Dictionary, plant:Greenhouse_Plant, plant_index:int, octree_manager:MMIOctreeManager, 
	brush_placement_area:BrushPlacementArea, container_transform:Transform, painting_changes:PaintingChanges):
	
	# We create a grid, detect overlaps and get a list of raycast positions that aren't occupied
	brush_placement_area.init_grid_data(plant.density_per_units, brush.behavior_strength)
	# Previously we expanded the search area by 1 unit to eliminate placing instances right outside our area as it moves
	# (since these would seem onoccupied to the placement logic)
	# But I turned on placement amount limiter and it looks surprisingly fine
	# And as a result doesn't cause a bug where small brushes with small density place plants *too* rarely (because of that search expansion)
	brush_placement_area.init_placement_overlaps(octree_manager, 0)#1)
	var raycast_positions = brush_placement_area.get_valid_raycast_positions()
	for raycast_position in raycast_positions:
		# We raycast along the surface normal using brush sphere as our bounds
		raycast_position[0] = container_transform.xform(raycast_position[0])
		raycast_position[1] = container_transform.xform(raycast_position[1])
		var ray_result = space_state.intersect_ray(raycast_position[0], raycast_position[1])
		
		if !ray_result.empty() && ray_result.collider.collision_layer & collision_mask:
			if !TransformGenerator.is_plant_slope_allowed(ray_result.normal, plant): continue
			# Generate transforms and add them to the array
			var member_pos = container_transform.affine_inverse().xform(ray_result.position)
			var plant_transform:Transform = TransformGenerator.generate_plant_transform(member_pos, ray_result.normal, plant, randomizer)
			var placement_transform:PlacementTransform = PlacementTransform.new(member_pos, ray_result.normal, plant_transform)
			painting_changes.add_change(PaintingChanges.ChangeType.APPEND, plant_index, placement_transform, placement_transform)
