@tool
extends Node3D


#-------------------------------------------------------------------------------
# A Node responsible for baking a Gardener to user-editable Nodes
#-------------------------------------------------------------------------------


const FunLib = preload("../utility/fun_lib.gd")
const BakerPlantSettings = preload("baker_plant_settings.gd")
const MMIOctreeNode = preload("../arborist/mmi_octree/mmi_octree_node.gd")
const OctreeLeaf = preload("../arborist/mmi_octree/octree_leaf.gd")
const UndoRedoInterface = preload("../utility/undo_redo_interface.gd")
const EditorInterfaceInterface = preload("../utility/editor_interface_interface.gd")

var _plant_settings: Array[BakerPlantSettings] = []
var _keep_original_gardener: bool = true

var _undo_redo = null

signal LOD_bake_finished




#-------------------------------------------------------------------------------
# Bake menu
#-------------------------------------------------------------------------------


# Create and initialize a bake menu
static func make_bake_menu():
	var bake_menu := Button.new()
	bake_menu.text = "Bake Gardener"
	bake_menu.set_theme_type_variation("FlatButton");
	bake_menu.add_user_signal("bake_requested")
	bake_menu.tooltip_text = "Bake the selected Gardener to actual nodes\nIn the scene hierarchy"
	
	var popup = PopupPanel.new()
	var popup_vb = VBoxContainer.new()
	var popup_tab = TabContainer.new()
	var popup_separator = HSeparator.new()
	var popup_check_keep_gardener = CheckBox.new()
	var popup_button_bake_gardener = Button.new()
	popup_separator.size_flags_vertical = Control.SIZE_SHRINK_BEGIN | Control.SIZE_EXPAND
	popup_check_keep_gardener.text = "Keep original Gardener"
	popup_check_keep_gardener.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	popup_check_keep_gardener.tooltip_text = "Whether to keep the Gardener in the scene hierarchy\nOr delete it after baking"
	popup_button_bake_gardener.text = "Bake Gardener to Nodes"
	popup_button_bake_gardener.pressed.connect(func (): bake_menu.emit_signal("bake_requested"))
	popup_tab.custom_minimum_size.x = 400
	
	bake_menu.add_child(popup)
	popup.add_child(popup_vb)
	popup_vb.add_child(popup_tab)
	popup_vb.add_child(popup_separator)
	popup_vb.add_child(popup_check_keep_gardener)
	popup_vb.add_child(popup_button_bake_gardener)
	
	return bake_menu


func bake_menu_pressed(bake_menu: Button):
	var popup: PopupPanel = bake_menu.get_child(0, false)
	var pos := bake_menu.get_screen_position() + bake_menu.size
	popup.set_position(pos - Vector2(popup.get_contents_minimum_size().x / 2, 0))
	popup.popup()


func up_to_date_baker_menu(bake_menu: Button, gardener, p_plant_names: Array, p_base_control: Control, p_resource_previewer):
	_plant_settings = []
	_keep_original_gardener = true
	var popup: PopupPanel = bake_menu.get_child(0, false)
	var popup_tab: TabContainer = popup.get_child(0, false).get_child(0, false)
	var popup_check_keep_gardener: CheckBox = popup.get_child(0, false).get_child(2, false)
	popup_check_keep_gardener.set_pressed_no_signal(_keep_original_gardener)
	
	FunLib.free_children(popup_tab)
	var octree_root_nodes = gardener.arborist.get_all_octree_root_nodes()
	for i in octree_root_nodes.size():
		var root_octree_node = octree_root_nodes[i]
		var max_lod = root_octree_node.shared_LOD_variants.size() - 1
		var plant_settings = BakerPlantSettings.new(max_lod)
		var plant_settings_vb = VBoxContainer.new()
		_plant_settings.append(plant_settings)
		for input_field in plant_settings.create_input_fields(p_base_control, p_resource_previewer).values():
			plant_settings_vb.add_child(input_field)
		if p_plant_names[i] == "":
			plant_settings_vb.name = "Plant %d" % [i]
		else:
			plant_settings_vb.name = p_plant_names[i]
		popup_tab.add_child(plant_settings_vb)
	popup.reset_size()




#-------------------------------------------------------------------------------
# Baking
#-------------------------------------------------------------------------------


func request_bake(bake_menu: Button, gardener: Node3D):
	if !is_instance_valid(gardener.get_parent()):
		push_error("Cannot bake a Gardener when it is the scene's root!")
	
	var popup: PopupPanel = bake_menu.get_child(0, false)
	var popup_check_keep_gardener: CheckBox = popup.get_child(0, false).get_child(2, false)
	_keep_original_gardener = popup_check_keep_gardener.button_pressed
	var baked_gardener := Node3D.new()
	baked_gardener.name = "Baked_" + gardener.name
	baked_gardener.transform = gardener.transform
	var octree_root_nodes = gardener.arborist.get_all_octree_root_nodes()
	var node: MMIOctreeNode
	var lifo_nodes: Array[MMIOctreeNode]
	var MMI: MultiMeshInstance3D
	var spawned_node3d_container: Node3D
	var spawned_node3d: Node3D
	var mesh_LOD: int
	var node3d_LOD: int
	var camera_origin = gardener.arborist.camera_to_use.global_transform.origin
	var external_baking_requested := false
	
	# Baking meshes
	for i in range(octree_root_nodes.size()):
		lifo_nodes = [octree_root_nodes[i]]
		external_baking_requested = false
		if _plant_settings[i].mesh_lod_picking != BakerPlantSettings.LODPickingType.NONE:
			match _plant_settings[i].mesh_lod_picking:
				BakerPlantSettings.LODPickingType.MANUAL:
					if !_plant_settings[i].mesh_kill_instances:
						external_baking_requested = true
						gardener.arborist.update_LODs_for_baking_override_kill_distance(camera_origin, -1, LOD_bake_finished)
					mesh_LOD = _plant_settings[i].mesh_lod_idx
				BakerPlantSettings.LODPickingType.SCENE_ORIGIN:
					if !_plant_settings[i].mesh_kill_instances:
						external_baking_requested = true
						gardener.arborist.update_LODs_for_baking_override_kill_distance(Vector3.ZERO, -1, LOD_bake_finished)
					else:
						external_baking_requested = true
						gardener.arborist.update_LODs_for_baking(Vector3.ZERO, LOD_bake_finished)
				BakerPlantSettings.LODPickingType.CURRENT_CAMERA:
					if !_plant_settings[i].mesh_kill_instances:
						external_baking_requested = true
						gardener.arborist.update_LODs_for_baking_override_kill_distance(camera_origin, -1, LOD_bake_finished)
			
			while !lifo_nodes.is_empty():
				node = lifo_nodes.pop_back()
				
				if node.leaf._current_state & OctreeLeaf.StateType.MESH_DEPS_INITIALIZED:
					if RenderingServer.multimesh_get_instance_count(node.leaf._RID_multimesh) > 0:
						match _plant_settings[i].mesh_lod_picking:
							BakerPlantSettings.LODPickingType.CURRENT_CAMERA, BakerPlantSettings.LODPickingType.SCENE_ORIGIN:
								mesh_LOD = node.leaf._active_LOD_index
						MMI = MultiMeshInstance3D.new()
						baked_gardener.add_child(MMI, true)
						MMI.transform = gardener.transform
						MMI.cast_shadow = node.shared_LOD_variants[mesh_LOD].cast_shadow
						MMI.multimesh = MultiMesh.new()
						MMI.multimesh.transform_format = MultiMesh.TRANSFORM_3D
						MMI.multimesh.mesh = node.shared_LOD_variants[mesh_LOD].mesh
						MMI.multimesh.use_colors = false
						MMI.multimesh.use_custom_data = false
						MMI.multimesh.instance_count = RenderingServer.multimesh_get_instance_count(node.leaf._RID_multimesh)
						MMI.multimesh.visible_instance_count = RenderingServer.multimesh_get_visible_instances(node.leaf._RID_multimesh)
						MMI.multimesh.buffer = RenderingServer.multimesh_get_buffer(node.leaf._RID_multimesh)
						#MMI.multimesh.custom_aabb = RenderingServer.multimesh_get_custom_aabb(node.leaf._RID_multimesh)
				
				for child in node.child_nodes:
					lifo_nodes.append(child)
			
			# If we forced any synchonous LOD updates in the Arborist
			# First we gather the data ('while' loop above)
			# Then we notify the Arborist that we're done working with this data
			if external_baking_requested:
				LOD_bake_finished.emit()
	
	# Baking Node3Ds
	for i in range(octree_root_nodes.size()):
		lifo_nodes = [octree_root_nodes[i]]
			
		external_baking_requested = false
		if _plant_settings[i].node3d_lod_picking != BakerPlantSettings.LODPickingType.NONE:
			match _plant_settings[i].node3d_lod_picking:
				BakerPlantSettings.LODPickingType.MANUAL:
					if !_plant_settings[i].node3d_kill_instances:
						external_baking_requested = true
						gardener.arborist.update_LODs_for_baking_override_kill_distance(camera_origin, -1, LOD_bake_finished)
					node3d_LOD = _plant_settings[i].node3d_lod_idx
				BakerPlantSettings.LODPickingType.SCENE_ORIGIN:
					if !_plant_settings[i].node3d_kill_instances:
						external_baking_requested = true
						gardener.arborist.update_LODs_for_baking_override_kill_distance(Vector3.ZERO, -1, LOD_bake_finished)
					else:
						external_baking_requested = true
						gardener.arborist.update_LODs_for_baking(Vector3.ZERO, LOD_bake_finished)
				BakerPlantSettings.LODPickingType.CURRENT_CAMERA:
					if !_plant_settings[i].node3d_kill_instances:
						external_baking_requested = true
						gardener.arborist.update_LODs_for_baking_override_kill_distance(camera_origin, -1, LOD_bake_finished)
			
			while !lifo_nodes.is_empty():
				node = lifo_nodes.pop_back()
				
				if node.leaf._current_state & OctreeLeaf.StateType.SPATIAL_DEPS_INITIALIZED:
					if node.leaf._spawned_spatial_container.get_child_count() > 0:
						match _plant_settings[i].node3d_lod_picking:
							BakerPlantSettings.LODPickingType.CURRENT_CAMERA, BakerPlantSettings.LODPickingType.SCENE_ORIGIN:
								node3d_LOD = node.leaf._active_LOD_index
						spawned_node3d_container = Node3D.new()
						baked_gardener.add_child(spawned_node3d_container, true)
						for leaf_spawned_spatial in node.leaf._spawned_spatial_container.get_children():
							spawned_node3d = node.shared_LOD_variants[node3d_LOD].spawned_spatial.instantiate()
							spawned_node3d_container.add_child(spawned_node3d, true)
							spawned_node3d.transform = leaf_spawned_spatial.transform
				
				for child in node.child_nodes:
					lifo_nodes.append(child)
		
		# If we forced any synchonous LOD updates in the Arborist
		# First we gather the data ('while' loop above)
		# Then we notify the Arborist that we're done working with this data
		if external_baking_requested:
			LOD_bake_finished.emit()
	
	# Commiting UndoRedo action
	var scene_owner = gardener.get_tree().edited_scene_root
	var parent := gardener.get_parent()
	UndoRedoInterface.create_action(_undo_redo, "Bake selected Gardener", 0, false, self)
	UndoRedoInterface.add_do_method(_undo_redo, parent.add_child.bind(baked_gardener, true))
	UndoRedoInterface.add_do_method(_undo_redo, baked_gardener.propagate_call.bind("set_owner", [scene_owner], true))
	UndoRedoInterface.add_undo_method(_undo_redo, parent.remove_child.bind(baked_gardener))
	if !_keep_original_gardener:
		UndoRedoInterface.add_do_method(_undo_redo, parent.remove_child.bind(gardener))
		UndoRedoInterface.add_undo_method(_undo_redo, parent.add_child.bind(gardener, true))
		UndoRedoInterface.add_undo_method(_undo_redo, gardener.set_owner.bind(gardener.owner))
	
	UndoRedoInterface.add_do_method(_undo_redo, EditorInterfaceInterface.select_single_node.bind(baked_gardener))
	UndoRedoInterface.add_undo_method(_undo_redo, EditorInterfaceInterface.select_single_node.bind(gardener))
	
	UndoRedoInterface.add_do_reference(_undo_redo, baked_gardener)
	if !_keep_original_gardener:
		UndoRedoInterface.add_undo_reference(_undo_redo, gardener)
	
	UndoRedoInterface.commit_action(_undo_redo, true)
