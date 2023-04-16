@tool
extends RichTextLabel


@export var scrollbar_size = 24

func _ready():
	for child in get_children():
		if is_instance_of(child, VScrollBar):
			child.custom_minimum_size.x = scrollbar_size
		elif is_instance_of(child, HScrollBar):
			child.custom_minimum_size.y = scrollbar_size
