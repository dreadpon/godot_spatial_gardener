tool
extends "ui_if_thumbnail_base.gd"


#-------------------------------------------------------------------------------
# Stores a thumbnailable resource
# Allows to assign existing project files through a browsing popup or drag'n'drop
#-------------------------------------------------------------------------------

# TODO make it accept most thumbnailable Variants?


var _thumb = null



#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val, __labelText:String = "NONE", __prop_name:String = "", settings:Dictionary = {}).(__init_val, __labelText, __prop_name, settings):
	set_meta("class", "UI_IF_ThumbnailObject")


func _ready():
	_thumb = _generate_thumbnail()
	value_container.add_child(_thumb)
	_init_ui()




#-------------------------------------------------------------------------------
# Property management
#-------------------------------------------------------------------------------


func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	if prop_action is PA_PropSet || prop_action is PA_PropEdit:
		_update_ui_to_val(final_val)


func _update_ui_to_val(val):
	_queue_thumbnail(val, _thumb)


func set_thumb_interaction_feature_with_data(interaction_flag:int, val, data:Dictionary):
	set_thumb_interaction_feature(_thumb, interaction_flag, val)




#-------------------------------------------------------------------------------
# Request PropActions
#-------------------------------------------------------------------------------


func on_requested_clear(thumb):
	_request_prop_action(null, "PA_PropSet")


func on_check(state, thumb):
	emit_signal("requested_check", 0, state)


func on_label_edit(label_text, thumb):
	emit_signal("requested_label_edit", 0, label_text)


func on_press(thumb):
	emit_signal("requested_press", 0)




#-------------------------------------------------------------------------------
# Assign/clear project files to thumbnails
#-------------------------------------------------------------------------------


# Request a custom prop action to set the property of an owning object
func set_res_for_thumbnail(res:Resource, thumb):
	_request_prop_action(res, "PA_PropSet")
