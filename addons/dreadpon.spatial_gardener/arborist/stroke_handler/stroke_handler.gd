tool
extends Node

#-------------------------------------------------------------------------------
# A base object that initializes a BrushPlacementArea
# And generates neccessary PaintingChange depending on the stroke type it handles
#-------------------------------------------------------------------------------


const Logger = preload("../../utility/logger.gd")
const FunLib = preload("../../utility/fun_lib.gd")
const Greenhouse_Plant = preload("../../greenhouse/greenhouse_plant.gd")
const PlacementTransform = preload("../placement_transform.gd")
const Toolshed_Brush = preload("../../toolshed/toolshed_brush.gd")
const BrushPlacementArea = preload("../brush_placement_area.gd")
const TransformGenerator = preload("../transform_generator.gd")
const PaintingChanges = preload("../painting_changes.gd")
const MMIOctreeManager = preload("../mmi_octree/mmi_octree_manager.gd")


var randomizer:RandomNumberGenerator
var transform_generator:TransformGenerator

var brush:Toolshed_Brush
var plant_states:Array
var octree_managers:Array
var space_state:PhysicsDirectSpaceState
var collision_mask:int

var logger = null




#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


func _init(_brush:Toolshed_Brush, _plant_states:Array, _octree_managers:Array, _space_state:PhysicsDirectSpaceState, _collision_mask:int):
	set_meta("class", "StrokeHandler")
	
	brush = _brush
	plant_states = _plant_states
	octree_managers = _octree_managers
	space_state = _space_state
	collision_mask = _collision_mask
	
	randomizer = RandomNumberGenerator.new()
	randomizer.seed = OS.get_ticks_msec()
	logger = Logger.get_for(self)




#-------------------------------------------------------------------------------
# PaintingChange management
#-------------------------------------------------------------------------------


# A method for building PaintingChanges
func get_stroke_update_changes(brush_data:Dictionary, container_transform:Transform, node) -> PaintingChanges:
	var painting_changes = PaintingChanges.new()
	if brush.behavior_strength <= 0.0 && get_meta("class") == "SH_Paint": return painting_changes
	
	var msec_start = FunLib.get_msec()
	
	brush_data.brush_pos = container_transform.affine_inverse().xform(brush_data.brush_pos)
	
	for plant_index in range(0, plant_states.size()):
		if !plant_states[plant_index].plant_brush_active: continue
		var plant = plant_states[plant_index].plant
		
		var new_brush_data = modify_brush_data_to_plant(brush_data, plant)
		
		# BrushPlacementArea is the "brains" of my placement logic, so we initialize it here
		var brush_placement_area := BrushPlacementArea.new(new_brush_data.brush_pos, brush.shape_size * 0.5, new_brush_data.brush_normal, plant.offset_jitter_fraction)
		var octree_manager = octree_managers[plant_index]
		
		make_stroke_update_changes(new_brush_data, plant, plant_index, octree_manager, brush_placement_area, container_transform, painting_changes, node)
	
	var msec_end = FunLib.get_msec()
	debug_print_lifecycle("	Stroke %s changes update took: %s" % [get_meta("class"), FunLib.msec_to_time(msec_end - msec_start)])
	return painting_changes


# Called when the Painter brush stroke is updated (moved)
# To be overridden
func make_stroke_update_changes(brush_data:Dictionary, plant:Greenhouse_Plant, plant_index:int, 
	octree_manager:MMIOctreeManager, brush_placement_area:BrushPlacementArea, container_transform:Transform, painting_changes:PaintingChanges, node):
	return null


# Modify the brush data according to the plant
# Fow now just used to snap the brush_pos to the virtual density grid of a plant
func modify_brush_data_to_plant(brush_data:Dictionary, plant) -> Dictionary:
	# Disabled for now as it feels weird when erasing plants on low density
	# Plants that are clearly overlapped visually aren't overlapped after snapping (due to origin changing it's position)
	return brush_data.duplicate()
	
	var new_brush_data := brush_data.duplicate()
	var point_distance:float = BrushPlacementArea.get_point_distance(plant.density_per_units, brush.behavior_strength)
	var cell_coord:Vector3 = new_brush_data.brush_pos / point_distance
	cell_coord = Vector3(round(cell_coord.x), round(cell_coord.y), round(cell_coord.z))
	new_brush_data.brush_pos = cell_coord * point_distance
	return new_brush_data




#-------------------------------------------------------------------------------
# Debug
#-------------------------------------------------------------------------------


func debug_print_lifecycle(string:String):
	if !FunLib.get_setting_safe("dreadpons_spatial_gardener/debug/arborist_log_lifecycle", false): return
	logger.info(string)
