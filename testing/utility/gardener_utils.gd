@tool


const GenericUtils = preload("generic_utils.gd")
const Landscape_SCN = preload("../assets/landscape/landscape.tscn")
const PaintBodyData = preload("paint_body_data.gd")
const OctreeNode = preload("res://addons/dreadpon.spatial_gardener/arborist/mmi_octree/mmi_octree_node.gd")




static func populate_node_with_surfaces(parent_node:Node, landscape_surface:bool = true, plane_surfaces:bool = true) -> Array:
	var painting_data := []
	if landscape_surface:
		painting_data.append(PaintBodyData.new("landscape", Vector3.ZERO, Basis.IDENTITY, 40.0))
	if plane_surfaces:
		painting_data.append_array([
			PaintBodyData.new("plane", Vector3(120, 0, 120), Basis(Quaternion.from_euler(Vector3(PI/4, PI/4, 0))), 10.0),
			PaintBodyData.new("plane", Vector3(-120, 0, 120), Basis(Quaternion.from_euler(Vector3(PI/2, 7*PI/4, 0))), 13.33),
			PaintBodyData.new("plane", Vector3(120, 0, -120), Basis(Quaternion.from_euler(Vector3(7*PI/4, 3*PI/4, 0))), 16.66),
			PaintBodyData.new("plane", Vector3(-120, 0, -120), Basis(Quaternion.from_euler(Vector3(PI, 5*PI/4, 0))), 20.0)])
	
	for data in painting_data:
		var mesh_instance = null
		
		match data.type:
			"landscape":
				mesh_instance = Landscape_SCN.instantiate()
				mesh_instance.global_transform = Transform3D(data.basis, data.origin)
				mesh_instance.scale = Vector3(data.extent, data.extent, data.extent) * 2.0
			"plane":
				mesh_instance = MeshInstance3D.new()
				mesh_instance.mesh = BoxMesh.new()
				mesh_instance.mesh.size = Vector3(data.extent, 1, data.extent) * 2.0
				
				mesh_instance.global_transform = Transform3D(data.basis, data.origin)
				mesh_instance.create_trimesh_collision()
		
		parent_node.add_child(mesh_instance, true)
		mesh_instance.owner = parent_node.get_tree().get_edited_scene_root()
	
	return painting_data




static func snapshot_tree(root_node:Node) -> Dictionary:
	var snapshot := {}
	snapshot[cleanup_node_name(root_node.name)] = snapshot_node(root_node)
	
	return snapshot


static func snapshot_node(node:Node) -> Dictionary:
	var snapshot := {}
	for child in node.get_children(true):
		snapshot[cleanup_node_name(child.name)] = snapshot_node(child)
	
	return snapshot


static func snapshot_octrees(octree_managers:Array):
	var snapshots := []
	for octree_manager in octree_managers:
		snapshots.append(snapshot_octree(octree_manager.root_octree_node))
	return snapshots


static func snapshot_octree(root_octree_node:OctreeNode) -> Dictionary:
	var snapshot := {}
	var address_string = str(root_octree_node.get_address_string())
	snapshot[address_string] = snapshot_octree_node(root_octree_node)
	
	return snapshot


static func snapshot_octree_node(octree_node:OctreeNode):
	var snapshot := {}
	if octree_node.child_nodes.size() > 0:
		for child in octree_node.child_nodes:
			var address_string = str(child.get_address_string())
			snapshot[address_string] = snapshot_octree_node(child)
	else:
		return octree_node.get_member_count()
	
	return snapshot


const node_name_forbidden_symbols = [".", ":", "@", "/", "\"", "%"]
static func cleanup_node_name(p_name: String) -> String:
	for char in node_name_forbidden_symbols:
		p_name = p_name.replace(char, "_")
	return p_name
