tool
extends "ui_action_thumbnail.gd"


#-------------------------------------------------------------------------------
# An action thumbnail version that is pressed to create new action thumbnails
#-------------------------------------------------------------------------------


func _init():
	set_meta("class", "UI_ActionThumbnailCreateInst")


#-------------------------------------------------------------------------------
# Resizing
#-------------------------------------------------------------------------------


func update_size_step2():
	var button_rect = Vector2(button_size, button_size)
	var to_margin = float(thumb_size - button_size) * 0.5
	
	.update_size_step2()
	
	texture_rect_nd.set_size(button_rect)
	texture_rect_nd.set_position(Vector2(to_margin, to_margin))




#-------------------------------------------------------------------------------
# Interaction flags
#-------------------------------------------------------------------------------


# Overrides parent function, since it has no features to set
func enable_features_to_flag(flag:int, state:bool):
	return
