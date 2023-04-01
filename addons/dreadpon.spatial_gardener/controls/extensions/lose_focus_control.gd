@tool
extends LineEdit



# Release focus from a child node when pressing enter
func _gui_input(event):
	if has_focus():
		if event is InputEventKey && !event.pressed:
			if event.keycode == KEY_ENTER || event.keycode == KEY_ESCAPE:
				release_focus()
				if self is LineEdit:
					caret_column = 0
