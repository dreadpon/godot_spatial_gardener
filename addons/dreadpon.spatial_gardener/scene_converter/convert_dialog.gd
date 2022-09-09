tool
extends WindowDialog


signal confirm_pressed
signal cancel_pressed
signal dont_ask_again_toggled(state)



func _ready():
	$'%TreeScenes'.connect('item_selected', self, '_on_tree_item_selected')


func _on_tree_item_selected():
	var selected_item: TreeItem = $'%TreeScenes'.get_selected()
	if !selected_item: return
	selected_item.set_checked(0, !selected_item.is_checked(0))
	selected_item.deselect(0)


func add_scenes(scenes: Array):
	$'%TreeScenes'.clear()
	$'%TreeScenes'.hide_root = true
	var root = $'%TreeScenes'.create_item()
	for scene in scenes:
		var item: TreeItem = $'%TreeScenes'.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_checked(0, true)
		item.set_text(0, scene)


func get_selected_scenes() -> Array:
	var selected_scenes = []
	var child_item: TreeItem = $'%TreeScenes'.get_root().get_children()
	while child_item != null:
		if child_item.is_checked(0):
			selected_scenes.append(child_item.get_text(0))
		child_item = child_item.get_next()
	return selected_scenes


func should_mk_backups():
	return $'%ButtonBackup'.pressed




func _on_ButtonConfirm_pressed():
	emit_signal('confirm_pressed')


func _on_ButtonCancel_pressed():
	emit_signal('cancel_pressed')


func _on_ButtonDontAskAgain_toggled(button_pressed):
	emit_signal('dont_ask_again_toggled', button_pressed)


func _on_ConvertDialog_about_to_show():
	$'%ButtonBackup'.pressed = true
	$'%ButtonDontAskAgain'.pressed = false
