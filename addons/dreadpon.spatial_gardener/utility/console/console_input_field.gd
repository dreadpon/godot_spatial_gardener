@tool
extends TextEdit




func _process(delta):
	if visible:
		call_deferred("_hide_scrollbar")


func _hide_scrollbar():
	for child in get_children():
		if is_instance_of(child, VScrollBar):
			child.visible = false
		elif is_instance_of(child, HScrollBar):
			child.visible = false
