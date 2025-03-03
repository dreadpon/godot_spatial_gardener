@tool
extends Resource

#-------------------------------------------------------------------------------
# A script responsible for picking and transforming an individual octree instance
# Has multiple modes of selection 
# (Mesh, First found MeshInstance3D on a Spawned Spatial, Node3D physics body on a Spawned Spatial)
#-------------------------------------------------------------------------------


const OctreeLeaf = preload("../arborist/mmi_octree/octree_leaf.gd")
const FrustumQuery = preload("frustum_query.gd")
const EditorInterfaceInterface = preload("../utility/editor_interface_interface.gd")
const Toolshed_Brush = preload("../toolshed/toolshed_brush.gd")
const PaintingChanges = preload("../arborist/painting_changes.gd")
const Placeform = preload("../arborist/placeform.gd")

enum QueryMode {
	MESH, NODE3D_FIRST_MESH, NODE3D_BODY
}

var proxy_node_instance: Node3D
var proxy_mesh_instance: MeshInstance3D
var picked_instance = null
var last_proxy_transform: Transform3D
var selection_exists: bool = false

var query_mode: QueryMode = QueryMode.MESH
var collision_mask: int = 1
var is_preprocess_enabled: bool = true

var gardener_root:Node3D = null

signal member_transformed(changes: PaintingChanges)




#-------------------------------------------------------------------------------
# Initialization and lifecycle
#-------------------------------------------------------------------------------


func _init(p_gardener_root):
	resource_local_to_scene = true
	gardener_root = p_gardener_root
	
	proxy_node_instance = Node3D.new()
	proxy_mesh_instance = MeshInstance3D.new()
	gardener_root.add_child(proxy_node_instance, true, Node.INTERNAL_MODE_FRONT)
	proxy_node_instance.add_child(proxy_mesh_instance, true, Node.INTERNAL_MODE_FRONT)
	proxy_node_instance.visible = false


# Free/nullify all references that may cause memory leaks
# NOTE: we assume these refs are recreated whenever the tree is entered again
# NOTE: currently unused, kept just in case
# func free_circular_refs():
# 	picked_instance = null
# 	selection_exists = false
# 	if is_instance_valid(proxy_node_instance):
# 		if proxy_node_instance.is_inside_tree():
# 			gardener_root.remode_child(proxy_node_instance)
# 		proxy_node_instance.queue_free()
# 		proxy_mesh_instance.queue_free()
# 		proxy_node_instance = null
# 		proxy_mesh_instance = null


func forwarded_input(camera:Camera3D, event):
	var handled := false
	if !selection_exists:
		if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && event.pressed:
			handled = _query()
	
	return handled


func update(delta):
	if selection_exists:
		if EditorInterfaceInterface.get_selected_nodes().size() != 1 || EditorInterfaceInterface.get_selected_nodes()[0] != proxy_node_instance:
			deselect_proxy()
	
		else:
			if proxy_node_instance.global_transform != last_proxy_transform:
				last_proxy_transform = proxy_node_instance.global_transform
				proxy_update()
				_query()


func update_all_props_to_active_brush(brush: Toolshed_Brush):
	query_mode = brush.behavior_selection_mode
	collision_mask = brush.behavior_selection_collision_mask
	is_preprocess_enabled = brush.behavior_enable_selection_preprocess




#-------------------------------------------------------------------------------
# Query
#-------------------------------------------------------------------------------


func _query() -> bool:
	if selection_exists: return false
	
	var viewport: Viewport = EditorInterfaceInterface.get_current_viewport()
	var camera: Camera3D = viewport.get_camera_3d()
	
	if !viewport || !camera: return false
	
	var root_nodes = gardener_root.arborist.get_all_octree_root_nodes()
	var instance_intersection_candidates = []
	var instance_intersections = []
	
	var mouse_pos = viewport.get_mouse_position()
	var ray_start = camera.project_ray_origin(mouse_pos)
	var ray_end = camera.project_ray_origin(mouse_pos) + camera.project_ray_normal(mouse_pos) * camera.far
	
	# Query using Godot's physics system
	# This one's the simplest, but relies on metadata assigned to spawned Node3Ds
	if query_mode == QueryMode.NODE3D_BODY:
		var ray_params = PhysicsRayQueryParameters3D.create(ray_start, ray_end, collision_mask)
		var results = gardener_root.get_world_3d().direct_space_state.intersect_ray(ray_params)
		if results && gardener_root.is_ancestor_of(results.collider):
			var path = gardener_root.get_path_to(results.collider)
			var spawned_spatial_path = "/".join(path.get_concatenated_names().split("/").slice(0, 2))
			var spawned_spatial_instance = gardener_root.get_node(spawned_spatial_path)
			var spawned_spatial_container_path = "/".join(path.get_concatenated_names().split("/").slice(0, 1))
			var spawned_spatial_container_instance = gardener_root.get_node(spawned_spatial_container_path)
			var shape_owner = results.collider.shape_owner_get_owner(results.collider.shape_find_owner(results.shape))
			var mesh = shape_owner.shape.get_debug_mesh()
			var member_idx := -1
			var plant_idx := -1
			var octree_node = null
			for i in root_nodes.size():
				plant_idx = i
				var root_node = root_nodes[i]
				octree_node = root_node.find_child_by_address(spawned_spatial_container_instance.get_meta("octree_address"))
				if octree_node:
					for k in spawned_spatial_container_instance.get_child_count():
						if spawned_spatial_container_instance.get_child(k) == spawned_spatial_instance:
							member_idx = k
							break
					if member_idx >= 0:
						break
			
			if member_idx >= -1:
				var instance_intersection_candidate = {"node": octree_node, "plant_idx": plant_idx, "member_idx": member_idx, "placeform": octree_node.get_placeform(member_idx)}
				instance_intersections.append([instance_intersection_candidate, results.position, mesh])
	
	# Query by gathering instances under a mouse cursor and manually raycasting against their geometry triangles
	elif query_mode == QueryMode.MESH || query_mode == QueryMode.NODE3D_FIRST_MESH:
		if !gardener_root.visible: return false
		
		# Obstruction preprocess (obstruction is checked only for Meshes, NOT physics bodies)
		if is_preprocess_enabled:
			var intersecting_render_server_instances := RenderingServer.instances_cull_ray(ray_start, ray_end, gardener_root.get_world_3d().scenario)
			var intersecting_polygonal_instances := []
			for id in intersecting_render_server_instances:
				var instance = instance_from_id(id)
				if instance is CSGShape3D || instance is MeshInstance3D || (instance is MultiMeshInstance3D && instance.multimesh && instance.multimesh.mesh):
					if gardener_root.is_ancestor_of(instance): continue
					instance_intersection_candidates.append({"polygonal_instance": instance})
		
		# TODO: this is probably a bad guess for frustum radius
		#		need some other, more universal way to handle close-by instances
		var frustum := FrustumQuery.new(camera, 100.0, false)
		for i in root_nodes.size():
			var root_node = root_nodes[i]
			instance_intersection_candidates.append_array(frustum.query_intersecting_positions(ray_start, ray_end, gardener_root.global_transform, root_node, i))
		
		var spatial_first_mesh_path: NodePath
		var intersection_meshes: Array[Mesh] = []
		var mesh_instance_transforms: Array[Transform3D] = []
		for instance_intersection_candidate in instance_intersection_candidates:
			intersection_meshes = []
			mesh_instance_transforms = []
			
			# Here we actually add our obstruction query results to the pool of meshes/transforms to check
			if instance_intersection_candidate.has("polygonal_instance"):
				if instance_intersection_candidate.polygonal_instance is CSGShape3D:
					intersection_meshes.append(instance_intersection_candidate.polygonal_instance.get_mesh())
					mesh_instance_transforms.append(instance_intersection_candidate.polygonal_instance.global_transform)
				elif instance_intersection_candidate.polygonal_instance is MeshInstance3D:
					intersection_meshes.append(instance_intersection_candidate.polygonal_instance.mesh)
					mesh_instance_transforms.append(instance_intersection_candidate.polygonal_instance.global_transform)
				elif instance_intersection_candidate.polygonal_instance is MultiMeshInstance3D:
					for i in instance_intersection_candidate.polygonal_instance.multimesh.instance_count:
						intersection_meshes.append(instance_intersection_candidate.polygonal_instance.multimesh.mesh)
						mesh_instance_transforms.append(instance_intersection_candidate.polygonal_instance.multimesh.get_instance_transform(i))
			
			# Here we add any instances overlapped by a frustum to the pool of meshes/transforms to check
			else:
				match query_mode:
					QueryMode.MESH:
						if instance_intersection_candidate.node.leaf.get_current_state() & OctreeLeaf.StateType.MESH_DEPS_INITIALIZED == 0:
							continue
						intersection_meshes.append(instance_intersection_candidate.node.leaf._mesh)
						mesh_instance_transforms.append(gardener_root.global_transform * instance_intersection_candidate.placeform[2])
					QueryMode.NODE3D_FIRST_MESH:
						if instance_intersection_candidate.node.leaf.get_current_state() & OctreeLeaf.StateType.SPATIAL_DEPS_INITIALIZED == 0:
							continue
						spatial_first_mesh_path = _get_packed_scene_first_node_rel_path(query_mode, instance_intersection_candidate.node.leaf._spawned_spatial)
						if spatial_first_mesh_path.is_empty(): continue
						var child_spatial = instance_intersection_candidate.node.leaf._spawned_spatial_container.get_child(instance_intersection_candidate.member_idx)
						var child_mesh = child_spatial.get_node(spatial_first_mesh_path)
						intersection_meshes.append(child_mesh.mesh)
						mesh_instance_transforms.append(child_mesh.global_transform)
			
			# Run actual geometry-triangle raycasts
			for i in intersection_meshes.size():
				var intersect_triangles_result = intersect_ray_triangles(ray_start, ray_end, mesh_instance_transforms[i], intersection_meshes[i])
				if intersect_triangles_result:
					instance_intersections.append([instance_intersection_candidate, intersect_triangles_result.position, intersection_meshes[i]])
					#[{"node": octree_node, "plant_index": plant_index, "member_idx": member_idx, "placeform": octree_node.get_placeform(member_idx)}, results.position]
	
	# Sort results of raycasts (both physical or geometry-based) and pick the closest one to camera
	if !instance_intersections.is_empty():
		instance_intersections.sort_custom(func(a, b): return (a[1] - ray_start).length_squared() < (b[1] - ray_start).length_squared())
		var instance_intersection_candidate = instance_intersections[0]
		if !instance_intersection_candidate[0].has("polygonal_instance"):
			picked_instance = instance_intersection_candidate[0].duplicate(true)
			var address = PackedByteArray()
			picked_instance.node.get_address(address)
			picked_instance.address = address
			#DebugDraw3D.draw_sphere(instance_intersection_candidate[1], 2.0, Color.RED, 60.0)
			var node_origin = gardener_root.global_transform * picked_instance.placeform[0]
			var mesh_trans = gardener_root.global_transform * picked_instance.placeform[2]
			var selection_mesh = instance_intersection_candidate[2]
			
			proxy_node_instance.global_transform = mesh_trans
			proxy_node_instance.global_position = node_origin
			proxy_mesh_instance.mesh = selection_mesh
			proxy_mesh_instance.global_transform = mesh_trans
			EditorInterfaceInterface.select_single_node(proxy_node_instance)
			last_proxy_transform = proxy_node_instance.global_transform
			selection_exists = true
	
	return picked_instance != null


func intersect_ray_triangles(ray_start: Vector3, ray_end: Vector3, p_instance_candidate_transform: Transform3D, p_mesh: Mesh) -> Dictionary:
	var trans: Transform3D = p_instance_candidate_transform
	var aabb: AABB = p_mesh.get_aabb()
	var aabb_trans: Transform3D = trans
	aabb_trans.origin = trans * (aabb.position + aabb.size * 0.5)
	if FrustumQuery.is_box_line_intersecting(aabb_trans, aabb.size * trans.basis.get_scale(), ray_start, ray_end, [], false, false):
		var points = PackedVector3Array(trans * p_mesh.get_faces())
		for i in range(0, points.size(), 3):
			var intersection_points := []
			if FrustumQuery.is_line_triangle_intersecting(
				ray_start, ray_end,
				points[i], points[i + 1], points[i + 2],
				intersection_points, false, false
			):
				# TODO: check if returning here is fine. Should be, as we care about ANY intersections for each given instance
				#		and do not need to store ALL of them
				#		this might theoretically present some sorting problems, but very unlikely to be relevant
				return {"position": intersection_points[0]}
	return {}


# Search a node of type within a PackedScene, return relative path
func _get_packed_scene_first_node_rel_path(p_node_type: QueryMode, p_scene: PackedScene) -> NodePath:
	if p_node_type == QueryMode.MESH: return ""
	var root_node: Node3D = p_scene.instantiate()
	var rel_path: NodePath = ""
	
	var node: Node3D = null
	var lifo_nodes := [root_node]
	while !lifo_nodes.is_empty():
		node = lifo_nodes.pop_back()
		
		match query_mode:
			QueryMode.NODE3D_FIRST_MESH:
				if node is MeshInstance3D:
					rel_path = root_node.get_path_to(node)
					break
			QueryMode.NODE3D_BODY:
				if node is PhysicsBody3D:
					rel_path = root_node.get_path_to(node)
					break
			
		for child in node.get_children():
			lifo_nodes.append(child)
	
	return rel_path




#-------------------------------------------------------------------------------
# Proxy handling
#-------------------------------------------------------------------------------


# Request instance transform update in response to proxy transform change
func proxy_update():
	var old_placeform = picked_instance.node.get_placeform(picked_instance.member_idx)
	var new_placeform = Placeform.mk(proxy_node_instance.global_transform.origin, old_placeform[1], proxy_mesh_instance.global_transform, old_placeform[3])
	new_placeform[0] = gardener_root.global_transform.affine_inverse() * new_placeform[0]
	new_placeform[2] = gardener_root.global_transform.affine_inverse() * new_placeform[2]
	
	var address = PackedByteArray()
	picked_instance.node.get_address(address)
	var changes = PaintingChanges.new()
	changes.add_change(
		PaintingChanges.ChangeType.SET, picked_instance.plant_idx,
		{"placeform": new_placeform, "index": picked_instance.member_idx, "address": address},
		{"placeform": old_placeform, "index": picked_instance.member_idx, "address": address})
	member_transformed.emit(changes)


func deselect_proxy():
	if selection_exists:
		selection_exists = false
		picked_instance = null


# Re-pick a previously picked instance after it was moved to a different OctreeNode
func on_transplanted_member(plant_index: int, new_address: PackedByteArray, new_idx: int, old_address: PackedByteArray, old_idx: int):
	if !picked_instance || picked_instance.is_empty(): return
	if picked_instance.plant_idx == plant_index && picked_instance.address == old_address && picked_instance.member_idx == old_idx:
		var root_nodes = gardener_root.arborist.get_all_octree_root_nodes()
		var octree_node = root_nodes[plant_index].find_child_by_address(new_address)
		picked_instance.node = octree_node
		picked_instance.address = new_address
		picked_instance.member_idx = new_idx
		picked_instance.placeform = octree_node.get_placeform(new_idx)
