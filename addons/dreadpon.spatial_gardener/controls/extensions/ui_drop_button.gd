tool
extends Button


#-------------------------------------------------------------------------------
# A button that accepts drop events
# Kind of surprised I need to attach a separate script for that functionality :/
#-------------------------------------------------------------------------------


signal dropped




func _init():
	set_meta("class", "UI_DropButton")


#-------------------------------------------------------------------------------
# Drag'n'drop handling
#-------------------------------------------------------------------------------


func can_drop_data(position, data):
	if typeof(data) == TYPE_DICTIONARY && data.has("files") && data["files"].size() == 1:
		return true


func drop_data(position, data):
	emit_signal("dropped", data["files"][0])
