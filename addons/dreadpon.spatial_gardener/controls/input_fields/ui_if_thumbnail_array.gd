@tool
extends "ui_if_thumbnail_base.gd"


#-------------------------------------------------------------------------------
# Stores an array of thumbnailable resources
# Allows to assign existing project files through a browsing popup or drag'n'drop
#-------------------------------------------------------------------------------


const UI_FlexGridContainer = preload("../extensions/ui_flex_grid_container.gd")


var add_create_inst_button:bool = true


# Needed to make flex_grid functional...
var scroll_intermediary:ScrollContainer = null
var flex_grid:UI_FlexGridContainer = null




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val, __labelText:String = "NONE", __prop_name:String = "", settings:Dictionary = {}):
	super(__init_val, __labelText, __prop_name, settings)
	set_meta("class", "UI_IF_ThumbnailArray")
	
	add_create_inst_button = settings.add_create_inst_button
	
	scroll_intermediary = ScrollContainer.new()
	scroll_intermediary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_intermediary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_intermediary.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	flex_grid = UI_FlexGridContainer.new()
	
	scroll_intermediary.add_child(flex_grid)
	container_box.add_child(scroll_intermediary)


func prepare_input_field(__init_val, __base_control:Control, __resource_previewer):
	super(__init_val, __base_control, __resource_previewer)


func _cleanup():
	super()
	if is_instance_valid(scroll_intermediary):
		scroll_intermediary.queue_free()
	if is_instance_valid(flex_grid):
		flex_grid.queue_free()



#-------------------------------------------------------------------------------
# Property management
#-------------------------------------------------------------------------------


func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
		_update_ui_to_val(final_val)
	elif is_instance_of(prop_action, PA_ArrayInsert):
		insert_element(final_val[prop_action.index], prop_action.index)
	elif is_instance_of(prop_action, PA_ArrayRemove):
		remove_element(prop_action.index)
	elif is_instance_of(prop_action, PA_ArraySet):
		set_element(final_val[prop_action.index], prop_action.index)


func _update_ui_to_val(val):
	if !is_node_ready():
		await ready
	FunLib.free_children(flex_grid)
	
	if add_create_inst_button:
		_add_thumb_create_inst()
	
	for i in range(0, val.size()):
		var thumb = _add_thumb()
		
		var element = val[i]
		if is_instance_of(element, Resource):
			_queue_thumbnail(element, thumb)
		else:
			thumb.set_thumbnail(null)
	
	super._update_ui_to_val(val.duplicate())


# Set possible interaction features for an action thumbnail
func set_thumb_interaction_feature_with_data(interaction_flag:int, val, data:Dictionary):
	if !is_node_ready():
		await ready
	if data.index >= flex_grid.get_child_count(): return
	if data.index < 0: return
	var thumb = flex_grid.get_child(data.index)
	set_thumb_interaction_feature(thumb, interaction_flag, val)




#-------------------------------------------------------------------------------
# Manage elements
#-------------------------------------------------------------------------------


# Add an action thumbnail that allows to add new elements
func _add_thumb_create_inst():
	if add_create_inst_button:
		var thumb = _generate_thumbnail_create_inst()
		flex_grid.add_child(thumb)


# Add a regular action thumbnail
func _add_thumb(index:int = -1):
	if !is_node_ready(): return
	var thumb = _generate_thumbnail()
	flex_grid.add_child(thumb)
	
	if index >= flex_grid.get_child_count():
		logger.warn("_add_thumb index %d is beyond maximum of %d. Clamping..." % [index, flex_grid.get_child_count() - 1])
		index = flex_grid.get_child_count() - 1
	if add_create_inst_button:
		if index < 0:
			flex_grid.move_child(thumb, flex_grid.get_child_count() - 2)
		else:
			flex_grid.move_child(thumb, index)
	return thumb


# Remove a regular action thumbnail
func _remove_thumb(index:int):
	if index >= flex_grid.get_child_count(): return
	if index < 0: return
	
	var thumb = flex_grid.get_child(index)
	flex_grid.remove_child(thumb)
	thumb.queue_free()




#-------------------------------------------------------------------------------
# Request PropActions
#-------------------------------------------------------------------------------


func on_requested_add():
	var index = flex_grid.get_child_count()
	if add_create_inst_button:
		index -= 1
	_request_prop_action(null, "PA_ArrayInsert", {"index": index})


func on_requested_delete(thumb):
	var index = thumb.get_index()
	_request_prop_action(null, "PA_ArrayRemove", {"index": index})


func on_requested_clear(thumb):
	var index = thumb.get_index()
	_request_prop_action(null, "PA_ArraySet", {"index": index})


func on_check(state, thumb):
	requested_check.emit(thumb.get_index(), state)


func on_label_edit(label_text, thumb):
	requested_label_edit.emit(thumb.get_index(), label_text)


func on_press(thumb):
	requested_press.emit(thumb.get_index())




#-------------------------------------------------------------------------------
# Manage elements of the current val
#-------------------------------------------------------------------------------


func insert_element(element, index:int):
	_add_thumb(index)
	_update_thumbnail(element, index)


func remove_element(index:int):
	_remove_thumb(index)


func set_element(element, index:int):
	_update_thumbnail(element, index)




#-------------------------------------------------------------------------------
# Assign/clear project files to thumbnails
#-------------------------------------------------------------------------------


# Request a custom prop action to set the property of an owning object
func set_res_for_thumbnail(res:Resource, thumb):
	var index = thumb.get_index()
	_request_prop_action(res, "PA_ArraySet", {"index": index})




#-------------------------------------------------------------------------------
# Manage thumbnails
#-------------------------------------------------------------------------------


func _update_thumbnail(res, index:int):
	if !is_node_ready(): return
	if index >= flex_grid.get_child_count(): return
	if index < 0: return
	
	_queue_thumbnail(res, flex_grid.get_child(index))
