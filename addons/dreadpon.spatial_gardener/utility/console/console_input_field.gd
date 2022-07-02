tool
extends TextEdit




func _process(delta):
	if visible:
		call_deferred("_hide_scrollbar")


func _hide_scrollbar():
	for child in get_children():
		if child is VScrollBar:
			child.visible = false
		elif child is HScrollBar:
			child.visible = false
