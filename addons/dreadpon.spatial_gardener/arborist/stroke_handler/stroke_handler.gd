tool
extends Node

#-------------------------------------------------------------------------------
# A base object that gathers plant positions/overlaps
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

var debug_draw_enabled: bool = false
var simplify_projection_frustum: bool = false

# Mouse position in screen space cached for one update cycle 
var _cached_mouse_pos: Vector2 = Vector2()

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
	
	debug_draw_enabled 			= FunLib.get_setting_safe("dreadpons_spatial_gardener/debug/stroke_handler_debug_draw", true)
	simplify_projection_frustum = FunLib.get_setting_safe("dreadpons_spatial_gardener/painting/simplify_projection_frustum", true)
	
	if debug_draw_enabled:
		debug_mk_debug_draw()




#-------------------------------------------------------------------------------
# PaintingChange management
#-------------------------------------------------------------------------------


# A method for building PaintingChanges
# If we have 'brush' in _init(), we do we need 'brush_data' you might ask
# That's because 'brush' gives us brush settings (size, strength, etc.)
# While 'brush_data' gives up-to-date transformations and surface normal of a brush in world-space 
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
	var octree_manager:MMIOctreeManager = octree_managers[plant_index]
	
	match brush.behavior_overlap_mode:
		
		Toolshed_Brush.OverlapMode.VOLUME:
			var plant_brush_data = volume_modify_brush_data_to_plant(brush_data, plant)
			# BrushPlacementArea is the "brains" of my placement logic, so we initialize it here
			var brush_placement_area := BrushPlacementArea.new(plant_brush_data.brush_pos, brush.shape_volume_size * 0.5, plant_brush_data.brush_normal, plant.offset_jitter_fraction)
			volume_get_stroke_update_changes(plant_brush_data, plant, plant_index, octree_manager, brush_placement_area, container_transform, painting_changes)
			
		Toolshed_Brush.OverlapMode.PROJECTION:
			# This will store dictionaries so it shares the same data structure as brush_placement_area.overlapped_octree_members
			# But with member itself added into the mix. It'll look like this:
			# [{"node_address": node_address, "member_index": member_index, "member": placement_transform}, ...]
			var members_in_brush := []
			var frustum_planes := []
			_cached_mouse_pos = camera.get_viewport().get_mouse_position()
			
			proj_define_frustum(brush_data, frustum_planes)
			proj_get_members_in_frustum(frustum_planes, members_in_brush,  octree_manager.root_octree_node, container_transform)
			proj_filter_members_to_brush_circle(members_in_brush, container_transform)
			if !brush.behavior_passthrough:
				proj_filter_obstructed_members(members_in_brush, container_transform)
			proj_get_stroke_update_changes(members_in_brush, plant, plant_index, octree_manager, painting_changes)




#-------------------------------------------------------------------------------
# Volume brush handling
#-------------------------------------------------------------------------------


func volume_modify_brush_data_to_container(brush_data:Dictionary, container_transform:Transform):
	brush_data = brush_data.duplicate()
	brush_data.brush_pos = container_transform.affine_inverse().xform(brush_data.brush_pos)
	return brush_data


# Modify the brush data according to the plant
func volume_modify_brush_data_to_plant(brush_data:Dictionary, plant) -> Dictionary:
	# Here used to be code to snap the brush_pos to the virtual density grid of a plant
	return brush_data.duplicate()


# Called when the Painter brush stroke is updated (moved)
# To be overridden
func volume_get_stroke_update_changes(brush_data:Dictionary, plant:Greenhouse_Plant, plant_index:int, octree_manager:MMIOctreeManager, 
	brush_placement_area:BrushPlacementArea, container_transform:Transform, painting_changes:PaintingChanges):
	return null




#-------------------------------------------------------------------------------
# Projection brush handling
#-------------------------------------------------------------------------------


func proj_filter_members_to_brush_circle(members_in_frustum: Array, container_transform:Transform):
	var brush_radius_squared: float = pow(brush.shape_projection_size * 0.5, 2.0)
	var viewport_size := camera.get_viewport().size
	
	for i in range(members_in_frustum.size() -1, -1, -1):
		var member_data = members_in_frustum[i]
		var placement = container_transform.xform(member_data.member.placement)
		var screen_space_pos := camera.unproject_position(placement)
		var dist_squared = (screen_space_pos - _cached_mouse_pos).length_squared()
		
		# Remove those outside brush radius
		if dist_squared > brush_radius_squared:
			members_in_frustum.remove(i)
		# Remove those outside viewport
		elif screen_space_pos.x < 0 || screen_space_pos.y < 0 || screen_space_pos.x > viewport_size.x || screen_space_pos.y > viewport_size.y:
			members_in_frustum.remove(i)


func proj_define_frustum(brush_data:Dictionary, frustum_planes: Array) -> Array:
	var brush_half_size = brush.shape_projection_size * 0.5
	var brush_rect := Rect2(-brush_half_size, -brush_half_size, brush.shape_projection_size, brush.shape_projection_size)
	var frustum_points := []
	frustum_points.resize(8)
	frustum_planes.resize(6)
	
	project_frustum_points(frustum_points, brush_rect)
	define_frustum_plane_array(frustum_planes, frustum_points)
	
	debug_draw_point_array(frustum_points)
	debug_draw_plane_array(frustum_planes, [frustum_points[0], frustum_points[2], frustum_points[4], frustum_points[6], frustum_points[4], frustum_points[7]])
	
	return frustum_planes


func proj_filter_obstructed_members(members_in_frustum: Array, container_transform:Transform):
	# This is a margin to offset our cast due to miniscule errors in placement
	# And built-in collision shape margin
	# Not off-setting an endpoint will mark some visible instances as obstructed
	var raycast_margin = FunLib.get_setting_safe("dreadpons_spatial_gardener/painting/projection_raycast_margin", 0.1)
	for i in range(members_in_frustum.size() -1, -1, -1):
		var member_data = members_in_frustum[i]
		var ray_start: Vector3 = camera.global_transform.origin
		var ray_vector = container_transform.xform(member_data.member.placement) - ray_start
		var ray_end: Vector3 = ray_start + ray_vector.normalized() * (ray_vector.length() - raycast_margin)
		var ray_result = space_state.intersect_ray(ray_start, ray_end)
		
		if !ray_result.empty() && ray_result.collider.collision_layer & collision_mask:
			members_in_frustum.remove(i)


# Called when the Painter brush stroke is updated (moved)
# To be overridden
func proj_get_stroke_update_changes(members_in_brush: Array, plant:Greenhouse_Plant, plant_index: int, octree_manager:MMIOctreeManager, painting_changes:PaintingChanges):
	return null




#-------------------------------------------------------------------------------
# Projection, intersection and other Projection-brush geometry
#-------------------------------------------------------------------------------


# Recursively iterate over octree nodes to find nodes and members within brush frustum
func proj_get_members_in_frustum(frustum_planes: Array, members_in_frustum: Array, octree_node: MMIOctreeNode, container_transform:Transform):
	var octree_node_transform := Transform(container_transform.basis, container_transform.xform(octree_node.center_pos))
	var octree_node_extents := Vector3(octree_node.extent, octree_node.extent, octree_node.extent)
	debug_draw_cube(octree_node_transform.origin, octree_node_extents, octree_node_transform.basis.get_rotation_quat(), octree_node_transform.basis)
	
	if is_box_intersecting_frustum(frustum_planes, octree_node_transform, octree_node_extents):
		if octree_node.is_leaf:
			var node_address = octree_node.get_address()
			for member_index in range(0, octree_node.members.size()):
				var member = octree_node.members[member_index]
				members_in_frustum.append({"node_address": node_address, "member_index": member_index, "member": member})
		else:
			for child_node in octree_node.child_nodes:
				proj_get_members_in_frustum(frustum_planes, members_in_frustum, child_node, container_transform)


# This is an approximation (but THIS frustum check IS MEANT to be an approximation, so it's fine)
# This WILL fail on cube's screen-projected 'corners'
# Since technically it will intersect some planes of our frustum
# Which is fine because we perform distance checks to individual members later on
func is_box_intersecting_frustum(frustum_planes: Array, box_transform: Transform, box_extents: Vector3):
	# Extents == half-size
	var oriented_box_extents = [box_extents.x * box_transform.basis.x, box_extents.y * box_transform.basis.y, box_extents.z * box_transform.basis.z]
	var box_points := [
		box_transform.origin + oriented_box_extents[0] + oriented_box_extents[1] + oriented_box_extents[2],
		box_transform.origin + oriented_box_extents[0] + oriented_box_extents[1] - oriented_box_extents[2],
		box_transform.origin + oriented_box_extents[0] - oriented_box_extents[1] + oriented_box_extents[2],
		box_transform.origin + oriented_box_extents[0] - oriented_box_extents[1] - oriented_box_extents[2],
		box_transform.origin - oriented_box_extents[0] + oriented_box_extents[1] + oriented_box_extents[2],
		box_transform.origin - oriented_box_extents[0] - oriented_box_extents[1] + oriented_box_extents[2],
		box_transform.origin - oriented_box_extents[0] + oriented_box_extents[1] - oriented_box_extents[2],
		box_transform.origin - oriented_box_extents[0] - oriented_box_extents[1] - oriented_box_extents[2],
	]
	debug_draw_point_array(box_points, Color.yellow)
	
	for plane in frustum_planes:
		var points_inside := 0
		for point in box_points:
			points_inside += 1 if plane.is_point_over(point) else 0
		
		if points_inside == 0:
			return false
	return true



# Project frustum points from screen-space to world-space
func project_frustum_points(frustum_points: Array, brush_rect: Rect2):
	# A simple version for frustum projection which assumes four corners of the screen in world-space
	# To be roughly at camera's origin (camera.near is the default 0.05 and thus negligible)
	if simplify_projection_frustum:
		var origin_point = project_point(0.0)
		# Upper left, near + far
		frustum_points[0] = origin_point
		frustum_points[1] = project_point(camera.far - 0.1, Vector2(brush_rect.position.x, 	brush_rect.position.y))
		# Lower left, near + far
		frustum_points[2] = origin_point
		frustum_points[3] = project_point(camera.far - 0.1, Vector2(brush_rect.position.x, 	brush_rect.end.y))
		# Lower right, near + far
		frustum_points[4] = origin_point
		frustum_points[5] = project_point(camera.far - 0.1, Vector2(brush_rect.end.x, 		brush_rect.end.y))
		# Upper right, near + far
		frustum_points[6] = origin_point
		frustum_points[7] = project_point(camera.far - 0.1, Vector2(brush_rect.end.x, 		brush_rect.position.y))
	
	# A complex version for frustum projection which uses camera.near for bigger accuracy
	# Relevant when camera.near is greater than default of 0.05 (like 1.0 or 2.0)
	else:
		# Upper left, near + far
		project_frustum_point_pair(frustum_points, 0, 1, Vector2(brush_rect.position.x, brush_rect.position.y))
		# Lower left, near + far
		project_frustum_point_pair(frustum_points, 2, 3, Vector2(brush_rect.position.x, brush_rect.end.y))
		# Lower right, near + far
		project_frustum_point_pair(frustum_points, 4, 5, Vector2(brush_rect.end.x, 		brush_rect.end.y))
		# Upper right, near + far
		project_frustum_point_pair(frustum_points, 6, 7, Vector2(brush_rect.end.x, 		brush_rect.position.y))


func project_frustum_point_pair(frustum_points: Array, idx_0: int, idx_1: int, offset: Vector2):
	frustum_points[idx_0] = project_point(camera.near, offset)
	frustum_points[idx_1] = project_point(camera.far - 0.1, offset)


# Define an array of 6 frustum planes
func define_frustum_plane_array(frustum_planes: Array, frustum_points: Array):
	frustum_planes[0] = define_frustum_plane(frustum_points[0], frustum_points[3], frustum_points[1])
	frustum_planes[1] = define_frustum_plane(frustum_points[2], frustum_points[5], frustum_points[3])
	frustum_planes[2] = define_frustum_plane(frustum_points[4], frustum_points[7], frustum_points[5])
	frustum_planes[3] = define_frustum_plane(frustum_points[6], frustum_points[1], frustum_points[7])
	if simplify_projection_frustum:
		# Since all points involved here will be the same point due to simplification (see 'project_frustum_points()')
		# Approximate the points forming a plane by using camera's basis vectors 
		frustum_planes[4] = define_frustum_plane(frustum_points[4], frustum_points[2] - camera.global_transform.basis.x, frustum_points[0] + camera.global_transform.basis.y)
	else:
		# Here all our points are different, so use them as-is
		frustum_planes[4] = define_frustum_plane(frustum_points[4], frustum_points[2], frustum_points[0])
	frustum_planes[5] = define_frustum_plane(frustum_points[7], frustum_points[1], frustum_points[3])


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
	
	return plane


func project_point(distance: float, offset: Vector2 = Vector2.ZERO) -> Vector3:
	return camera.project_position(_cached_mouse_pos + offset, distance)




#-------------------------------------------------------------------------------
# Debug
#-------------------------------------------------------------------------------


func debug_print_lifecycle(string:String):
	if !FunLib.get_setting_safe("dreadpons_spatial_gardener/debug/arborist_log_lifecycle", false): return
	logger.info(string)


func debug_mk_debug_draw():
	var context = camera.get_tree().edited_scene_root.find_node('Gardener').get_parent()
	if !context.has_node('DebugDraw'):
		var debug_draw := DebugDraw.new()
		debug_draw.name = 'DebugDraw'
		context.add_child(debug_draw)


func debug_draw_plane_array(planes: Array, origin_points: Array, color: Color = Color.red):
	if !debug_draw_enabled: return
	for idx in range(0, planes.size()):
		debug_draw_plane(origin_points[idx], planes[idx], color)


func debug_draw_point_array(points: Array, color: Color = Color.green):
	if !debug_draw_enabled: return
	for point in points:
		debug_draw_point(point, color)


func debug_draw_plane(draw_origin: Vector3, plane: Plane, color: Color = Color.red):
	if !debug_draw_enabled: return
	var context = camera.get_tree().edited_scene_root.find_node('Gardener').get_parent()
	context.get_node('DebugDraw').draw_plane(draw_origin, camera.far * 0.25, plane.normal, color, context, 2.0, camera.global_transform.basis.y, 10.0)


func debug_draw_point(draw_origin: Vector3, color: Color = Color.green):
	if !debug_draw_enabled: return
	var context = camera.get_tree().edited_scene_root.find_node('Gardener').get_parent()
	context.get_node('DebugDraw').draw_cube(draw_origin, Vector3.ONE, Quat(), color, context, 10.0)


func debug_draw_cube(draw_origin: Vector3, extents: Vector3, rotation: Quat, basis: Basis = Basis(), color: Color = Color.blue):
	if !debug_draw_enabled: return
	var context = camera.get_tree().edited_scene_root.find_node('Gardener').get_parent()
	extents = Vector3(extents.x * basis.x.length(), extents.y * basis.y.length(), extents.z * basis.z.length())
	context.get_node('DebugDraw').draw_cube(draw_origin, extents, rotation, color, context, 10.0)
