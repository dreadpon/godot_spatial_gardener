@tool
extends RichTextLabel


@export var scrollbar_size = 24

func _ready():
	for child in get_children():
		if child is VScrollBar:
			child.minimum_size.x = scrollbar_size
		elif child is HScrollBar:
			child.minimum_size.y = scrollbar_size
