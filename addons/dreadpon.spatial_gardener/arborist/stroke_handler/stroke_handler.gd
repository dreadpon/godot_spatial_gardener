tool
extends Node

#-------------------------------------------------------------------------------
# A base object that initializes a BrushPlacementArea
# And generates neccessary PaintingChange depending on the stroke type it handles
#-------------------------------------------------------------------------------


const Logger = preload("../../utility/logger.gd")
const FunLib = preload("../../utility/fun_lib.gd")
const DebugDraw = preload("../../utility/debug_draw.gd")
const Greenhouse_Plant = preload("../../greenhouse/greenhouse_plant.gd")
const PlacementTransform = preload("../placement_transform.gd")
const Toolshed_Brush = preload("../../toolshed/toolshed_brush.gd")
const BrushPlacementArea = preload("../brush_placement_area.gd")
const TransformGenerator = preload("../transform_generator.gd")
const PaintingChanges = preload("../painting_changes.gd")
const MMIOctreeManager = preload("../mmi_octree/mmi_octree_manager.gd")
const MMIOctreeNode = preload("../mmi_octree/mmi_octree_node.gd")


var randomizer:RandomNumberGenerator
var transform_generator:TransformGenerator

var brush:Toolshed_Brush
var plant_states:Array
var octree_managers:Array
var space_state:PhysicsDirectSpaceState
var camera: Camera
var collision_mask:int

var logger = null




#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


func _init(_brush:Toolshed_Brush, _plant_states:Array, _octree_managers:Array, _space_state:PhysicsDirectSpaceState, _camera: Camera, _collision_mask:int):
	set_meta("class", "StrokeHandler")
	
	brush = _brush
	plant_states = _plant_states
	octree_managers = _octree_managers
	space_state = _space_state
	camera = _camera
	collision_mask = _collision_mask
	
	randomizer = RandomNumberGenerator.new()
	randomizer.seed = OS.get_ticks_msec()
	logger = Logger.get_for(self)




#-------------------------------------------------------------------------------
# PaintingChange management
#-------------------------------------------------------------------------------


# A method for building PaintingChanges
func get_stroke_update_changes(brush_data:Dictionary, container_transform:Transform) -> PaintingChanges:
	var painting_changes = PaintingChanges.new()
	if should_abort_early(brush_data): return painting_changes
	
	var msec_start = FunLib.get_msec()
	
	brush_data = modify_brush_data_to_container(brush_data, container_transform)
	
	for plant_index in range(0, plant_states.size()):
		if !plant_states[plant_index].plant_brush_active: continue
		var plant = plant_states[plant_index].plant
		
		handle_plant_stroke(brush_data, container_transform, plant, plant_index, painting_changes)
	
	var msec_end = FunLib.get_msec()
	debug_print_lifecycle("	Stroke %s changes update took: %s" % [get_meta("class"), FunLib.msec_to_time(msec_end - msec_start)])
	return painting_changes


# Are there any conditions that force us to abort before anything starts?
func should_abort_early(brush_data:Dictionary):
	return false


func modify_brush_data_to_container(brush_data:Dictionary, container_transform:Transform) -> Dictionary:
	match brush.behavior_overlap_mode:
		Toolshed_Brush.OverlapMode.VOLUME:
			return volume_modify_brush_data_to_container(brush_data, container_transform)
	return brush_data


func handle_plant_stroke(brush_data:Dictionary, container_transform:Transform, plant:Greenhouse_Plant, plant_index:int, painting_changes:PaintingChanges):
	match brush.behavior_overlap_mode:
		Toolshed_Brush.OverlapMode.VOLUME:
			var plant_brush_data = volume_modify_brush_data_to_plant(brush_data, plant)
			# BrushPlacementArea is the "brains" of my placement logic, so we initialize it here
			var brush_placement_area := BrushPlacementArea.new(plant_brush_data.brush_volume_pos, brush.shape_volume_size * 0.5, plant_brush_data.brush_normal, plant.offset_jitter_fraction)
			var octree_manager = octree_managers[plant_index]
			volume_get_stroke_update_changes(plant_brush_data, plant, plant_index, octree_manager, brush_placement_area, container_transform, painting_changes)
		Toolshed_Brush.OverlapMode.PROJECTION:
			var octree_manager:MMIOctreeManager = octree_managers[plant_index]
			var frustum_planes := []
			var members_in_brush := []
			
			var context = camera.get_tree().edited_scene_root.find_node('Gardener').get_parent()
			if !context.has_node('DebugDraw'):
				var debug_draw := DebugDraw.new()
				debug_draw.name = 'DebugDraw'
				context.add_child(debug_draw)
			
			proj_define_frustum(brush_data, frustum_planes)
			proj_get_members_in_frustum(frustum_planes, members_in_brush,  octree_manager.root_octree_node, container_transform)
			proj_filter_members_to_brush_circle(members_in_brush, container_transform)
			proj_get_stroke_update_changes(members_in_brush, plant_index, painting_changes)




#-------------------------------------------------------------------------------
# Volume brush handling
#-------------------------------------------------------------------------------


func volume_modify_brush_data_to_container(brush_data:Dictionary, container_transform:Transform):
	brush_data = brush_data.duplicate()
	brush_data.brush_volume_pos = container_transform.affine_inverse().xform(brush_data.brush_volume_pos)
	return brush_data


# Modify the brush data according to the plant
func volume_modify_brush_data_to_plant(brush_data:Dictionary, plant) -> Dictionary:
	# Here used to be code to snap the brush_volume_pos to the virtual density grid of a plant
	return brush_data.duplicate()


# Called when the Painter brush stroke is updated (moved)
# To be overridden
func volume_get_stroke_update_changes(brush_data:Dictionary, plant:Greenhouse_Plant, plant_index:int, octree_manager:MMIOctreeManager, 
	brush_placement_area:BrushPlacementArea, container_transform:Transform, painting_changes:PaintingChanges):
	return null




#-------------------------------------------------------------------------------
# Projection brush handling
#-------------------------------------------------------------------------------


# Called when the Painter brush stroke is updated (moved)
# To be overridden
func proj_get_stroke_update_changes(members_in_brush: Array, plant_index: int, painting_changes:PaintingChanges):
	return null


func proj_define_frustum(brush_data:Dictionary, frustum_planes: Array) -> Array:
	var brush_half_size = brush.shape_projection_size * 0.5
	var bush_rect := Rect2(-brush_half_size, -brush_half_size, brush.shape_projection_size, brush.shape_projection_size)
	var frustum_points := []
	frustum_points.resize(8)
	frustum_planes.resize(6)
	
	# Upper left, near + far
	project_frustum_points(frustum_points, 0, 1, Vector2(bush_rect.position.x, 	bush_rect.position.y))
	# Lower left, near + far
	project_frustum_points(frustum_points, 2, 3, Vector2(bush_rect.position.x, 	bush_rect.end.y))
	# Lower right, near + far
	project_frustum_points(frustum_points, 4, 5, Vector2(bush_rect.end.x, 		bush_rect.end.y))
	# Upper right, near + far
	project_frustum_points(frustum_points, 6, 7, Vector2(bush_rect.end.x, 		bush_rect.position.y))
	
	frustum_planes[0] = define_frustum_plane(frustum_points[0], frustum_points[3], frustum_points[1])
	frustum_planes[1] = define_frustum_plane(frustum_points[2], frustum_points[5], frustum_points[3])
	frustum_planes[2] = define_frustum_plane(frustum_points[4], frustum_points[7], frustum_points[5])
	frustum_planes[3] = define_frustum_plane(frustum_points[6], frustum_points[1], frustum_points[7])
	frustum_planes[4] = define_frustum_plane(frustum_points[4], frustum_points[2], frustum_points[0])
	frustum_planes[5] = define_frustum_plane(frustum_points[7], frustum_points[1], frustum_points[3])
	
	return frustum_planes


func proj_get_members_in_frustum(frustum_planes: Array, members_in_frustum: Array, octree_node: MMIOctreeNode, container_transform:Transform):
	var octree_node_transform := Transform(container_transform.basis, container_transform.xform(octree_node.center_pos))
	var octree_node_extents := Vector3(octree_node.extent, octree_node.extent, octree_node.extent)
	
#	var context = camera.get_tree().edited_scene_root.find_node('Gardener').get_parent()
#	context.get_node('DebugDraw').draw_cube(octree_node_transform.origin, octree_node_extents, octree_node_transform.basis.get_rotation_quat(), Color.red, context, 2.0)
	
	if is_box_intersecting_frustum(frustum_planes, octree_node_transform, octree_node_extents):
		if octree_node.is_leaf:
			members_in_frustum.append_array(octree_node.members)
		else:
			for child_node in octree_node.child_nodes:
				proj_get_members_in_frustum(frustum_planes, members_in_frustum, child_node, container_transform)


# This is an approximation (but THIS frustum check IS MEANT to be an approximation, so it's fine)
# This WILL fail on cube's screen-projected 'corners'
# Since technically it will intersect some planes of our frustum
func is_box_intersecting_frustum(frustum_planes: Array, box_transform: Transform, box_extents: Vector3):
	# Extents == half-size
	var box_points := [
		box_transform.origin + box_extents.x * box_transform.basis.x + box_extents.y * box_transform.basis.y + box_extents.z * box_transform.basis.z,
		box_transform.origin + box_extents.x * box_transform.basis.x + box_extents.y * box_transform.basis.y - box_extents.z * box_transform.basis.z,
		box_transform.origin + box_extents.x * box_transform.basis.x - box_extents.y * box_transform.basis.y + box_extents.z * box_transform.basis.z,
		box_transform.origin + box_extents.x * box_transform.basis.x - box_extents.y * box_transform.basis.y - box_extents.z * box_transform.basis.z,
		box_transform.origin - box_extents.x * box_transform.basis.x + box_extents.y * box_transform.basis.y + box_extents.z * box_transform.basis.z,
		box_transform.origin - box_extents.x * box_transform.basis.x - box_extents.y * box_transform.basis.y + box_extents.z * box_transform.basis.z,
		box_transform.origin - box_extents.x * box_transform.basis.x + box_extents.y * box_transform.basis.y - box_extents.z * box_transform.basis.z,
		box_transform.origin - box_extents.x * box_transform.basis.x - box_extents.y * box_transform.basis.y - box_extents.z * box_transform.basis.z,
	]
	
#	var context = camera.get_tree().edited_scene_root.find_node('Gardener').get_parent()
#	for box_point in box_points:
#		context.get_node('DebugDraw').draw_cube(box_point, Vector3.ONE, Quat(), Color.green, context, 2.0)
	
	var total_point_inside := 0
	
	for plane_idx in range(0, 6):
		var points_inside := 0
		
		for point in box_points:
			points_inside += 1 if (frustum_planes[plane_idx] as Plane).is_point_over(point) else 0
		
		if points_inside == 0:
			return false
	return true


func proj_filter_members_to_brush_circle(members_in_frustum: Array, container_transform:Transform):
	var mouse_pos := camera.get_viewport().get_mouse_position()
	var brush_radius: float = brush.shape_projection_size * 0.5
	for member in members_in_frustum.duplicate():
		var placement = container_transform.xform(member.placement)
		var screen_space_pos := camera.unproject_position(placement)
		var dist = (screen_space_pos - mouse_pos).length()
		if dist > brush_radius:
			members_in_frustum.erase(member)


func project_frustum_points(frustum_points: Array, idx_0: int, idx_1: int, offset: Vector2):
	frustum_points[idx_0] = project_point(camera.near, offset)
	frustum_points[idx_1] = project_point(camera.far - 0.1, offset)


# Plane equation is
# 		ax + by + xz + d = 0
# Or this with a common point on a plane
# 		a(x - x0) + b(y - y0) + c(z - z0) = 0
# Where (x0, y0, z0) is any point on the plane (lets use common_point)
#
# So plane equation becomes		
#		normal.x * ux - normal.x * common_point.x +
#		normal.y * uy - normal.y * common_point.y +
#		normal.z * uz - normal.z * common_point.z
#		= 0
# Where ux, uy, uz are unkown variables that are substituted when solving a plane equations
# 
# Now we combine or scalar values and move them to the right side
#		normal.x * ux + normal.y * uy + normal.z * uz 
#		= normal.x * common_point.x + normal.y * common_point.y + normal.z * common_point.z
#
#That should be it, distance to origin is 
#		d = normal.x * common_point.x + normal.y * common_point.y + normal.z * common_point.z
# Which is esentially a dot product :)
func define_frustum_plane(common_point: Vector3, point_0: Vector3, point_1: Vector3):
	var normal := (point_0 - common_point).cross(point_1 - common_point).normalized()
	var dist_to_origin = normal.dot(common_point)
	var plane = Plane(normal, dist_to_origin)
	
	var context = camera.get_tree().edited_scene_root.find_node('Gardener').get_parent()
#	context.get_node('DebugDraw').draw_plane(normal * plane.d, camera.far * 0.25, normal, Color.red, context, 2.0, camera.global_transform.basis.y, 2.0)
#	context.get_node('DebugDraw').draw_plane(common_point, camera.far * 0.25, normal, Color.red, context, 2.0, camera.global_transform.basis.y, 2.0)
	
	return plane


func project_point(distance: float, offset: Vector2 = Vector2.ZERO) -> Vector3:
	return camera.project_position(camera.get_viewport().get_mouse_position() + offset, distance)




#-------------------------------------------------------------------------------
# Debug
#-------------------------------------------------------------------------------


func debug_print_lifecycle(string:String):
	if !FunLib.get_setting_safe("dreadpons_spatial_gardener/debug/arborist_log_lifecycle", false): return
	logger.info(string)
