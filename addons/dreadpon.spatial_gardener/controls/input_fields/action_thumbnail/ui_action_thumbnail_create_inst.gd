@tool
extends "ui_action_thumbnail.gd"


#-------------------------------------------------------------------------------
# An action thumbnail version that is pressed to create new action thumbnails
#-------------------------------------------------------------------------------


func _init():
	set_meta("class", "UI_ActionThumbnailCreateInst")




#-------------------------------------------------------------------------------
# Resizing
#-------------------------------------------------------------------------------


func _set_default_textures():
	super._set_default_textures()
	%TextureRect.texture = new_texture




#-------------------------------------------------------------------------------
# Interaction flags
#-------------------------------------------------------------------------------


# Overrides parent function, since it has no features to set
func enable_features_to_flag(flag:int, state:bool):
	return
