extends Node


#-------------------------------------------------------------------------------
# A debug tool that draws lines and shapes in 3D space
# Can be used as an autoload script and remove drawn shapes after a delay
# Or as a static tool for creating geometry and attaching it to a scene
#-------------------------------------------------------------------------------


var active_geometry:Array = []
var cached_geometry:Array = []




func _init():
	set_meta("class", "DebugDraw")


# Instantiation through autoload allows to clear geometry after a delay
func _process(delta):
	var removed_active_geometry := []
	
	for data in active_geometry:
		if data.lifetime < 0.0:
			continue
		data.lifetime -= delta
		if data.lifetime <= 0.0:
			removed_active_geometry.append(data)
	
	for data in removed_active_geometry:
		active_geometry.erase(data)
		if is_instance_valid(data.geometry):
			data.geometry.queue_free()
	
	for data in cached_geometry:
		active_geometry.append(data)
	
	cached_geometry = []


# Manual clear for active geometry
func clear_cached_geometry():
	var removed_active_geometry := []
	for data in active_geometry:
		removed_active_geometry.append(data)
	
	for data in removed_active_geometry:
		active_geometry.erase(data)
		if is_instance_valid(data.geometry):
			data.geometry.queue_free()



# Draw a polygonal 3D line
# And set it on a timer
func draw_line(start:Vector3, end:Vector3, color:Color, node_context:Spatial, width:float = 0.1, lifetime := 0.0):
	var geom = static_draw_line(start, end, color, node_context, width)
	cached_geometry.append({"geometry": geom, "lifetime": lifetime})


# Draw a polygonal 3D line
# Origin represents line's start position, not it's center
static func static_draw_line(start:Vector3, end:Vector3, color:Color, node_context:Spatial, width:float = 0.1) -> ImmediateGeometry:
	if node_context == null: return null
	
	var geom = ImmediateGeometry.new()
	node_context.add_child(geom)
	
	var half_width = width * 0.5
	var length = (end - start).length()
	
	var z_axis = (end - start).normalized()
	var y_axis = Vector3(0, 1, 0)
	if abs(z_axis.dot(y_axis)) >= 0.9:
		y_axis = Vector3(1, 0, 0)
	var x_axis = y_axis.cross(z_axis)
	y_axis = z_axis.cross(x_axis)
	
	geom.global_transform.origin = start
	geom.global_transform.basis = Basis(x_axis, y_axis, z_axis).orthonormalized()
	
	var points := PoolVector3Array()
	points.append_array([
		Vector3(-half_width, half_width, 0),
		Vector3(half_width, half_width, 0),
		Vector3(half_width, -half_width, 0),
		Vector3(-half_width, -half_width, 0),
		Vector3(-half_width, half_width, length),
		Vector3(half_width, half_width, length),
		Vector3(half_width, -half_width, length),
		Vector3(-half_width, -half_width, length)
	])
	
	geom.begin(PrimitiveMesh.PRIMITIVE_TRIANGLES)
	
	geom.add_vertex(points[0])
	geom.add_vertex(points[5])
	geom.add_vertex(points[4])
	
	geom.add_vertex(points[0])
	geom.add_vertex(points[1])
	geom.add_vertex(points[5])
	
	geom.add_vertex(points[1])
	geom.add_vertex(points[6])
	geom.add_vertex(points[5])
	
	geom.add_vertex(points[1])
	geom.add_vertex(points[2])
	geom.add_vertex(points[6])
	
	geom.add_vertex(points[2])
	geom.add_vertex(points[7])
	geom.add_vertex(points[6])
	
	geom.add_vertex(points[2])
	geom.add_vertex(points[3])
	geom.add_vertex(points[7])
	
	geom.add_vertex(points[4])
	geom.add_vertex(points[3])
	geom.add_vertex(points[0])
	
	geom.add_vertex(points[4])
	geom.add_vertex(points[7])
	geom.add_vertex(points[3])
	
	geom.add_vertex(points[0])
	geom.add_vertex(points[2])
	geom.add_vertex(points[1])
	
	geom.add_vertex(points[0])
	geom.add_vertex(points[3])
	geom.add_vertex(points[2])
	
	geom.add_vertex(points[5])
	geom.add_vertex(points[7])
	geom.add_vertex(points[4])
	
	geom.add_vertex(points[5])
	geom.add_vertex(points[6])
	geom.add_vertex(points[7])
	
	geom.end()
	
	geom.material_override = SpatialMaterial.new()
	geom.material_override.flags_unshaded = true
	geom.material_override.albedo_color = color
	
	return geom


# Draw a line cube
# And set it on a timer
func draw_cube(pos:Vector3, extents:Vector3, rotation:Quat, color:Color, node_context:Spatial, lifetime := 0.0):
	var geom = static_draw_cube(pos, extents, rotation, color, node_context)
	cached_geometry.append({"geometry": geom, "lifetime": lifetime})


# Draw a line cube
static func static_draw_cube(pos:Vector3, extents:Vector3, rotation:Quat, color:Color, node_context:Spatial):
	if node_context == null: return
	
	var mesh_instance = MeshInstance.new()
	mesh_instance.transform.basis = Basis(rotation)
	mesh_instance.transform.origin = pos
	node_context.add_child(mesh_instance)
	
	mesh_instance.mesh = generate_cube(extents, color)
	mesh_instance.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	
	return mesh_instance


# Generate a line cube's ArrayMesh
static func generate_cube(extents:Vector3, color:Color):
	var mesh := ArrayMesh.new()
	
	var points := PoolVector3Array()
	points.append_array([
		Vector3(-extents.x, -extents.y, -extents.z),
		Vector3(-extents.x, -extents.y, extents.z),
		Vector3(-extents.x, extents.y, extents.z),
		Vector3(-extents.x, extents.y, -extents.z),
		
		Vector3(extents.x, -extents.y, -extents.z),
		Vector3(extents.x, -extents.y, extents.z),
		Vector3(extents.x, extents.y, extents.z),
		Vector3(extents.x, extents.y, -extents.z),
	])
	
	var vertices := PoolVector3Array()
	vertices.append_array([
		points[0], points[1],
		points[1], points[2],
		points[2], points[3],
		points[3], points[0],
		points[4], points[5],
		points[5], points[6],
		points[6], points[7],
		points[7], points[4],
		points[0], points[4],
		points[1], points[5],
		points[2], points[6],
		points[3], points[7],
	])
	
	var colors := PoolColorArray()
	for i in range(0, 24):
		colors.append(color)
	
	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = vertices
	arrays[ArrayMesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	
	var material := SpatialMaterial.new()
	material.flags_unshaded = true
	material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, material)
	
	return mesh


# Draw a line plane
# And set it on a timer
func draw_plane(pos:Vector3, extents:float, normal:Vector3, color:Color, node_context:Spatial, normal_length: float = 1.0, up_vector: Vector3 = Vector3.UP, lifetime := 0.0):
	var geom = static_draw_plane(pos, extents, normal, color, node_context)
	cached_geometry.append({"geometry": geom, "lifetime": lifetime})


# Draw a line cube
static func static_draw_plane(pos:Vector3, extents:float, normal:Vector3, color:Color, node_context:Spatial, normal_length: float = 1.0, up_vector: Vector3 = Vector3.UP):
	if node_context == null: return
	
	normal = normal.normalized()
	var mesh_instance = MeshInstance.new()
	var basis = Basis()
	basis.z = normal
	basis.x = normal.cross(up_vector)
	basis.y = basis.x.cross(normal)
	basis.x = normal.cross(basis.y)
	mesh_instance.transform.basis = basis.orthonormalized()
	mesh_instance.transform.origin = pos
	node_context.add_child(mesh_instance)
	
	mesh_instance.mesh = generate_plane(extents, color, normal_length)
	mesh_instance.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	
	return mesh_instance


# Generate a line cube's ArrayMesh
static func generate_plane(extents:float, color:Color, normal_length: float):
	var mesh := ArrayMesh.new()
	
	var points := PoolVector3Array()
	points.append_array([
		Vector3(-extents, -extents, 0),
		Vector3(-extents, extents, 0),
		Vector3(extents, extents, 0),
		Vector3(extents, -extents, 0),
		Vector3(0, 0, 0),
		Vector3(0, 0, normal_length),
		Vector3(-extents, -extents, 0),
		Vector3(-extents, -extents, normal_length),
		Vector3(-extents, extents, 0),
		Vector3(-extents, extents, normal_length),
		Vector3(extents, extents, 0),
		Vector3(extents, extents, normal_length),
		Vector3(extents, -extents, 0),
		Vector3(extents, -extents, normal_length),
	])
	
	var vertices := PoolVector3Array()
	vertices.append_array([
		points[0], points[1],
		points[1], points[2],
		points[2], points[3],
		points[3], points[0],
		
		points[0], points[2],
		points[1], points[3],
		points[4], points[5],
		
		points[6], points[7],
		points[8], points[9],
		points[10], points[11],
		points[12], points[13],
	])
	
	var colors := PoolColorArray()
	for i in range(0, vertices.size()):
		colors.append(color)
	
	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = vertices
	arrays[ArrayMesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	
	var material := SpatialMaterial.new()
	material.flags_unshaded = true
	material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, material)
	
	return mesh
