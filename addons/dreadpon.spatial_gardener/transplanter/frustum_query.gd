@tool
extends RefCounted

#-------------------------------------------------------------------------------
# This script is responsible for querying octree instances within a camera frustum
# Used as a first step in picking an instance during Transplanter transformations
# 
# TODO: some code here duplicates code in stroke_handler.gd due to how development process was structured
#		this needs to be extracted in a function library to be shared anong these two scripts
# TODO: it makes sense to re-implement debug drawing in some capacity
#-------------------------------------------------------------------------------


const MMIOctreeNode = preload("../arborist/mmi_octree/mmi_octree_node.gd")

var camera: Camera3D
var queried_screen_pos: Vector2
var radius: float
var simplify_projection_frustum: bool = false

var frustum_planes: Array




#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


func _init(__camera: Camera3D, __radius: float, __simplify_projection_frustum := false): #, __debug_draw_enabled := false):
	camera = __camera
	radius = __radius
	simplify_projection_frustum = __simplify_projection_frustum




#-------------------------------------------------------------------------------
# Frustum definition and queries
#-------------------------------------------------------------------------------


func proj_define_frustum(frustum_planes: Array) -> Array:
	var brush_rect := Rect2(-radius, -radius, radius * 2, radius * 2)
	var frustum_points := []
	frustum_points.resize(8)
	frustum_planes.resize(6)
	
	project_frustum_points(frustum_points, brush_rect)
	define_frustum_plane_array(frustum_planes, frustum_points)
	
	#debug_draw_point_array(frustum_points)
	#debug_draw_plane_array(frustum_planes, [frustum_points[0], frustum_points[2], frustum_points[4], frustum_points[6], frustum_points[4], frustum_points[7]])
	
	return frustum_planes


func query_intersecting_positions(ray_start: Vector3, ray_end: Vector3, container_transform, oc_node: MMIOctreeNode, plant_idx: int):
	var intersected_positions := []
	
	proj_get_placeforms_data_at_point(ray_start, ray_end, intersected_positions, oc_node, container_transform, plant_idx)
	
	#if !brush.behavior_passthrough:
		#proj_filter_obstructed_placeforms(intersected_positions, container_transform)
	return intersected_positions


# Recursively iterate over octree nodes to find nodes and members within brush frustum
func proj_get_placeforms_data_at_point(ray_start: Vector3, ray_end: Vector3, intersected_positions: Array, octree_node: MMIOctreeNode, container_transform: Transform3D, plant_idx: int):
	var octree_node_transform := Transform3D(container_transform.basis, container_transform * octree_node.center_pos)
	var octree_node_extents := Vector3(octree_node.extent, octree_node.extent, octree_node.extent)
	#debug_draw_cube(octree_node_transform.origin, octree_node_extents * 2.0, octree_node_transform.basis.get_rotation_quaternion(), octree_node_transform.basis)
	
	if is_box_line_intersecting(octree_node_transform, octree_node_extents * 2.0, ray_start, ray_end, [], false, false):
		if octree_node.is_leaf:
			for member_idx in range(0, octree_node.get_member_count()):
				var placeform = octree_node.get_placeform(member_idx)
				intersected_positions.append({"node": octree_node, "plant_idx": plant_idx, "member_idx": member_idx, "placeform": placeform})
		else:
			for child_node in octree_node.child_nodes:
				proj_get_placeforms_data_at_point(ray_start, ray_end, intersected_positions, child_node, container_transform, plant_idx)


static func is_box_line_intersecting(box_transform: Transform3D, box_size: Vector3, line_origin: Vector3, line_end: Vector3, intersection := [], draw_box := false, draw_line := false) -> bool:
	#if draw_box:
		#DebugDraw3D.draw_box(box_transform.origin, box_transform.basis.get_rotation_quaternion(), box_size, Color.BLUE, true, 1/60.0)
	#if draw_line:
		#DebugDraw3D.draw_line(line_origin, line_end, Color.BLUE, 60.0)#1/60.0)
	
	var rot_matrix = Transform3D()
	rot_matrix.basis = box_transform.basis.orthonormalized()
	
	var inv_matrix = Transform3D.IDENTITY
	inv_matrix.origin -= box_transform.origin
	inv_matrix = rot_matrix.inverse() * inv_matrix
	inv_matrix.origin -= box_transform.origin
	
	var transformed_line_origin = (line_origin - box_transform.origin) * rot_matrix#.inverse()
	var transformed_line_end = (line_end - box_transform.origin) * rot_matrix#.inverse()
	
	var result = is_AABB_line_intersecting(
		-box_size * 0.5, box_size * 0.5, 
		transformed_line_origin, transformed_line_end, intersection, false, false)
	
	#if draw_line && result:
		#var line_dir = (line_end - line_origin).normalized()
		#DebugDraw3D.draw_line(line_origin + line_dir * intersection[0], line_origin + line_dir * min(intersection[1], (line_end - line_origin).length()), Color.RED, 60.0)#1/60.0)
		#DebugDraw3D.draw_sphere(line_origin + line_dir * intersection[0], 1.2, Color.RED, 60.0)
		#DebugDraw3D.draw_sphere(line_origin + line_dir * min(intersection[1], (line_end - line_origin).length()), 1.2, Color.RED, 60.0)
	
	#if draw_box:
		#var color = Color.CYAN
		#if result: 
			#color = Color.RED
		#var obb_rot = box_transform.basis.orthonormalized().get_rotation_quaternion()
		#DebugDraw3D.draw_box(box_transform.origin, obb_rot, box_size, color, true, 60.0)#1/60.0)
	
	return result


static func is_AABB_line_intersecting(box_min: Vector3, box_max: Vector3, line_origin: Vector3, line_end: Vector3, intersection := [], draw_box := false, draw_line := false) -> bool:
	intersection.resize(2)
	intersection[0] = -1
	intersection[1] = -1
	
	var line_dir = (line_end - line_origin).normalized()
	var inv_dir = Vector3(1.0 / line_dir.x, 1.0 / line_dir.y, 1.0 / line_dir.z)
	var t_min = (box_min - line_origin) * inv_dir
	var t_max = (box_max - line_origin) * inv_dir
	
	var r_min = Vector3(min(t_min.x, t_max.x), min(t_min.y, t_max.y), min(t_min.z, t_max.z))
	var r_max = Vector3(max(t_min.x, t_max.x), max(t_min.y, t_max.y), max(t_min.z, t_max.z))
	
	var near = max(r_min.x, r_min.y, r_min.z)
	var far = min(r_max.x, r_max.y, r_max.z)
	
	#if draw_box:
		#DebugDraw3D.draw_aabb(AABB(box_min, box_max - box_min), Color.BLUE, 60.0)#1/60.0)
	#if draw_line:
		#DebugDraw3D.draw_line(line_origin, line_end, Color.BLUE, 60.0)#1/60.0)
	
	if near > far: return false
	if far < 0.0: return false
	
	if near > (line_end - line_origin).length(): return false
	
	intersection[0] = near
	intersection[1] = far
	
	#if draw_line:
		#DebugDraw3D.draw_line(line_origin + line_dir * near, line_origin + line_dir * min(far, (line_end - line_origin).length()), Color.RED, 60.0)#1/60.0)
	
	return true


static func is_line_triangle_intersecting(
	line_origin: Vector3, line_end: Vector3, 
	t0: Vector3, t1: Vector3, t2: Vector3, 
	intersection := [], draw_triangle := false, draw_line := false) -> bool:
	
	var normal := (t2 - t0).cross(t1 - t0)
	var line_vec := line_end - line_origin
	var line_to_plane_vec := t0 - line_origin
	var difference_fraction := line_to_plane_vec.dot(normal) / line_vec.dot(normal)
	var intersection_point = line_origin + difference_fraction * line_vec
	
	#if draw_triangle:
		#DebugDraw3D.draw_line(t0, t1, Color.BLUE, 60.0)
		#DebugDraw3D.draw_line(t1, t2, Color.BLUE, 60.0)
		#DebugDraw3D.draw_line(t2, t0, Color.BLUE, 60.0)
	
	#if draw_line:
		#DebugDraw3D.draw_line(line_origin, line_end, Color.BLUE, 60.0)
	
	if difference_fraction < 0 || difference_fraction > 1:
		return false
	
	var result = point_inside_triangle(intersection_point, t0, t1, t2, normal)
	#if draw_line && result:
		#DebugDraw3D.draw_sphere(intersection_point, 1.5, Color.RED, 60.0)
	
	if result:
		intersection.resize(1)
		intersection[0] = intersection_point
	
	return result


# Assumes point is already projected on the triangle plane
static func point_inside_triangle(point: Vector3, t0: Vector3, t1: Vector3, t2: Vector3, normal: Vector3):
	var area := Vector3(
		normal.dot((t1 - t0).cross(t2 - t0)),
		normal.dot((t1 - point).cross(t2 - point)),
		normal.dot((t2 - point).cross(t0 - point))
	)
	var bary: Vector3
	bary.x = area.y / area.x
	bary.y = area.z / area.x
	bary.z = 1.0 - bary.x - bary.y
	
	var inside := bary.x >= 0.0 && bary.y >= 0.0 && bary.z >= 0.0
	return inside


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
# Now we combine our scalar values and move them to the right side
#		normal.x * ux + normal.y * uy + normal.z * uz 
#		= normal.x * common_point.x + normal.y * common_point.y + normal.z * common_point.z
#
# That should be it, distance to origin is 
#		d = normal.x * common_point.x + normal.y * common_point.y + normal.z * common_point.z
# Which is esentially a dot product :)
func define_frustum_plane(common_point: Vector3, point_0: Vector3, point_1: Vector3):
	var normal := (point_0 - common_point).cross(point_1 - common_point).normalized()
	var dist_to_origin = normal.dot(common_point)
	var plane = Plane(normal, dist_to_origin)
	
	return plane


func project_point(distance: float, offset: Vector2 = Vector2.ZERO) -> Vector3:
	return camera.project_position(queried_screen_pos + offset, distance)




#-------------------------------------------------------------------------------
# Debug drawing
#-------------------------------------------------------------------------------


#func debug_draw_plane_array(planes: Array, origin_points: Array, color: Color = Color.RED):
	#if !debug_draw_enabled: return
	#for idx in range(0, planes.size()):
		#debug_draw_plane(origin_points[idx], planes[idx], color)
#
#
#func debug_draw_point_array(points: Array, color: Color = Color.GREEN):
	#if !debug_draw_enabled: return
	#for point in points:
		#debug_draw_point(point, color)


#func debug_draw_plane(draw_origin: Vector3, plane: Plane, color: Color = Color.RED):
	#return
	#if !debug_draw_enabled: return
	#DebugDraw3D.draw_plane(plane, color, draw_origin, 0.05)
#
#
#func debug_draw_point(draw_origin: Vector3, color: Color = Color.GREEN):
	#return
	#if !debug_draw_enabled: return
	#DebugDraw3D.draw_box(draw_origin, Quaternion(), Vector3.ONE, color, true, 0.05)
#
#
#func debug_draw_cube(draw_origin: Vector3, size: Vector3, rotation: Quaternion, basis: Basis = Basis(), color: Color = Color.BLUE):
	#if !debug_draw_enabled: return
	#DebugDraw3D.draw_box(draw_origin, rotation, size, color, true, 0.05)
