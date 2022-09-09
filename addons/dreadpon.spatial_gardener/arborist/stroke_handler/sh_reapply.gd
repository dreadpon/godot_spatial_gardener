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
	create_painting_changes(brush_placement_area.overlapped_member_data, plant, plant_index, octree_manager, painting_changes)


func proj_get_stroke_update_changes(placeform_data_array: Array, plant:Greenhouse_Plant, plant_index: int, octree_manager:MMIOctreeManager, painting_changes:PaintingChanges):
	create_painting_changes(placeform_data_array, plant, plant_index, octree_manager, painting_changes)


func create_painting_changes(placeform_data_array: Array, plant:Greenhouse_Plant, plant_index: int, octree_manager:MMIOctreeManager, painting_changes:PaintingChanges):
	for placeform_data in placeform_data_array:
		var octree_node = octree_manager.root_octree_node.find_child_by_address(placeform_data.node_address)
		var placeform = octree_node.get_placeform(placeform_data.member_idx)
		
		# We use Vector3.to_string() to generate our reference keys
		# I assume it's fully deterministic at least in the scope of an individual OS
		var octree_member_key = str(placeform[0])
		if reapplied_octree_members.has(octree_member_key): continue
		reapplied_octree_members.append(octree_member_key)
		
		var plant_transform := TransformGenerator.generate_plant_transform(placeform[0], placeform[1], plant, randomizer)
		var new_placeform := Placeform.mk(placeform[0], placeform[1], plant_transform, placeform[3])
		
		# Painting changes here are non-standart: they actually have an octree node address and member index bundled
		# We can't reliably use an address when adding/removing members since the octree might grow/collapse
		# But here it's fine since we don't change the amount of members
		painting_changes.add_change(PaintingChanges.ChangeType.SET, plant_index,
			{"placeform": new_placeform, "index": placeform_data.member_idx, "address": placeform_data.node_address},
			{"placeform": placeform, "index": placeform_data.member_idx, "address": placeform_data.node_address})
