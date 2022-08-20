tool
extends LineEdit



# Release focus from a child node when pressing enter
func _gui_input(event):
	if has_focus():
		if event is InputEventKey && !event.pressed:
			if event.scancode == KEY_ENTER || event.scancode == KEY_ESCAPE:
				release_focus()
				if self is LineEdit:
					caret_position = 0
