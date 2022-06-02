tool
extends "stroke_handler.gd"


#-------------------------------------------------------------------------------
# Handle a single placement brush stroke
#-------------------------------------------------------------------------------

# Meant to be used with single mouse clicks
# Dragging while pressing will place as many instances as the framerate allows


func _init(_brush:Toolshed_Brush, _plant_states:Array, _octree_managers:Array, _space_state:PhysicsDirectSpaceState, _collision_mask:int).(
	_brush, _plant_states, _octree_managers, _space_state, _collision_mask):
	
	set_meta("class", "SH_Single")


func make_stroke_update_changes(brush_data:Dictionary, plant:Greenhouse_Plant, plant_index:int, 
	octree_manager:MMIOctreeManager, brush_placement_area:BrushPlacementArea, container_transform:Transform, painting_changes:PaintingChanges, node):
	
	var member_pos = brush_data.brush_pos
	
	var plant_transform:Transform = TransformGenerator.generate_plant_transform(member_pos, brush_data.brush_normal, plant, randomizer)
	var placement_transform:PlacementTransform = PlacementTransform.new(member_pos, brush_data.brush_normal, plant_transform)
	painting_changes.add_change(PaintingChanges.ChangeType.APPEND, plant_index, placement_transform, placement_transform)


# Overriding since we don't need any snapping in single placement
func modify_brush_data_to_plant(brush_data:Dictionary, plant) -> Dictionary:
	return brush_data.duplicate()
