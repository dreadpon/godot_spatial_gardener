@tool
extends ConfirmationDialog

signal confirm_pressed
signal cancel_pressed
signal dont_ask_again_toggled(state)




func _init():
	close_requested.connect(hide)


func _ready():
	$'%TreeScenes'.item_selected.connect(_on_tree_item_selected)


func _on_tree_item_selected():
	var selected_item: TreeItem = $'%TreeScenes'.get_selected()
	if !selected_item: return


func add_scenes(scenes: Array):
	$'%TreeScenes'.clear()
	var root = $'%TreeScenes'.create_item()
	for scene in scenes:
		var item: TreeItem = $'%TreeScenes'.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)
		item.set_checked(0, true)
		item.set_text(0, scene)


func get_selected_scenes() -> Array:
	var selected_scenes = []
	var child_item: TreeItem = $'%TreeScenes'.get_root().get_first_child()
	while child_item != null:
		if child_item.is_checked(0):
			selected_scenes.append(child_item.get_text(0))
		child_item = child_item.get_next()
	return selected_scenes


func should_mk_backups():
	return $'%ButtonBackup'.button_pressed




func _on_ButtonConfirm_pressed():
	confirm_pressed.emit()


func _on_ButtonCancel_pressed():
	cancel_pressed.emit()


func _on_ButtonDontAskAgain_toggled(pressed):
	dont_ask_again_toggled.emit(pressed)


func _on_ConvertDialog_about_to_show():
	$'%ButtonBackup'.button_pressed = true
	$'%ButtonDontAskAgain'.button_pressed = false
