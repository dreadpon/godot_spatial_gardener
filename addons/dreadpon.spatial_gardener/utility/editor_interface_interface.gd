extends Object

# TODO: this is a stub that we'll use when/if implementing runtime Gardener editing
static var _selected_nodes: Array[Node3D]




static func get_current_viewport():
	if Engine.is_editor_hint():
		return EditorInterface.get_editor_viewport_3d(0)
	
	return SceneTree.root.get_viewport()


static func get_selected_nodes():
	if Engine.is_editor_hint():
		return EditorInterface.get_selection().get_selected_nodes()
	
	return _selected_nodes


static func select_single_node(p_node: Node3D):
	if Engine.is_editor_hint():
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(p_node)
		return
	
	_selected_nodes.clear()
	_selected_nodes.append(p_node)


static func get_ui_scale() -> float:
	if Engine.is_editor_hint():
		return EditorInterface.get_editor_scale()
	return 1.0
