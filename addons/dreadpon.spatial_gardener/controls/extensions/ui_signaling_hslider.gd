extends HSlider


#-------------------------------------------------------------------------------
# Enable drag start/stop signaling feature
#-------------------------------------------------------------------------------

# TODO Use built-in features that are coming in Godot 3.5/4.0


signal drag_started
signal drag_stopped




func _gui_input(event):
	if event is InputEventMouseButton:
		if event.is_pressed():
			emit_signal("drag_started", value)
		else:
			emit_signal("drag_stopped", value)
