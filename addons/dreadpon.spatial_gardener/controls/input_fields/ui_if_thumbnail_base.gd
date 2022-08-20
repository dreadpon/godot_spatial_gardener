tool
extends "ui_input_field.gd"


#-------------------------------------------------------------------------------
# A base class for storing thumbnailable resources
#-------------------------------------------------------------------------------


const UI_ActionThumbnail_GD = preload("action_thumbnail/ui_action_thumbnail.gd")
const UI_ActionThumbnail = preload("action_thumbnail/ui_action_thumbnail.tscn")
const UI_ActionThumbnailCreateInst_GD = preload("action_thumbnail/ui_action_thumbnail_create_inst.gd")
const UI_ActionThumbnailCreateInst = preload("action_thumbnail/ui_action_thumbnail_create_inst.tscn")

const PRESET_NEW:Array = [UI_ActionThumbnail_GD.InteractionFlags.PRESS]
const PRESET_DELETE:Array = [UI_ActionThumbnail_GD.InteractionFlags.CLEAR, UI_ActionThumbnail_GD.InteractionFlags.DELETE]
const PRESET_PLANT_STATE:Array = [UI_ActionThumbnail_GD.InteractionFlags.DELETE, UI_ActionThumbnail_GD.InteractionFlags.SET_DRAG, UI_ActionThumbnail_GD.InteractionFlags.PRESS, UI_ActionThumbnail_GD.InteractionFlags.CHECK, UI_ActionThumbnail_GD.InteractionFlags.SHOW_COUNT, UI_ActionThumbnail_GD.InteractionFlags.EDIT_LABEL]
const PRESET_LOD_VARIANT:Array = [UI_ActionThumbnail_GD.InteractionFlags.DELETE, UI_ActionThumbnail_GD.InteractionFlags.PRESS, UI_ActionThumbnail_GD.InteractionFlags.SET_DRAG, UI_ActionThumbnail_GD.InteractionFlags.CLEAR]
const PRESET_RESOURCE:Array = [UI_ActionThumbnail_GD.InteractionFlags.SET_DIALOG, UI_ActionThumbnail_GD.InteractionFlags.SET_DRAG, UI_ActionThumbnail_GD.InteractionFlags.CLEAR]


var element_interaction_flags:Array = []
var accepted_classes:Array = []
var element_display_size:int = 100

var _base_control:Control = null
var _resource_previewer = null

var file_dialog:FileDialog = null


signal requested_press
signal requested_check
signal requested_label_edit
signal requested_edit_input_fields




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val, __labelText:String = "NONE", __prop_name:String = "", settings:Dictionary = {}).(__init_val, __labelText, __prop_name, settings):
	set_meta("class", "UI_IF_ThumbnailArray")
	
	_base_control = settings._base_control
	accepted_classes = settings.accepted_classes
	element_interaction_flags = settings.element_interaction_flags
	_resource_previewer = settings._resource_previewer
	element_display_size = settings.element_display_size
	file_dialog = FileDialog.new()
	file_dialog.mode = FileDialog.MODE_OPEN_FILE
	add_file_dialog_filter()
	file_dialog.current_dir = "res://"
	file_dialog.current_path = "res://"
	file_dialog.connect("popup_hide", self, "file_dialog_hidden")
	
	value_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	value_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_container.alignment = BoxContainer.ALIGN_BEGIN


func _enter_tree():
	if _base_control:
		_base_control.add_child(file_dialog)


func _exit_tree():
	if _base_control:
		if _base_control.get_children().has(file_dialog):
			_base_control.remove_child(file_dialog)


# Add filters for all accepted classes
# Wish we could automatically infer extensions :/
func add_file_dialog_filter():
	for accepted_class in accepted_classes:
		var extension := "tres"
		match accepted_class:
			"ArrayMesh":
				extension = "mesh"
			"PackedScene":
				extension = "tscn"
		file_dialog.add_filter("*.*%s ; %s" % [extension, accepted_class])




#-------------------------------------------------------------------------------
# Property management
#-------------------------------------------------------------------------------


# Callback for signals emitted from input_field_resource
func on_changed_interaction_feature(prop:String, interaction_flag:int, val, data:Dictionary):
	if prop_name == prop:
		set_thumb_interaction_feature_with_data(interaction_flag, val, data)


# Set possible interaction features for an action thumbnail
# To be overridden
func set_thumb_interaction_feature_with_data(interaction_flag:int, val, data:Dictionary):
	pass


# Shorthand for setting action thumbnail features
func set_thumb_interaction_feature(thumb, interaction_flag:int, val):
	if thumb && !(thumb is UI_ActionThumbnailCreateInst_GD):
		thumb.set_features_val_to_flag(interaction_flag, val)




#-------------------------------------------------------------------------------
# Manage elements
#-------------------------------------------------------------------------------


# Generate a regular action thumbnail
func _generate_thumbnail():
	var thumb := UI_ActionThumbnail.instance()
	thumb.init(element_display_size, int(float(element_display_size) * 0.24), element_interaction_flags)
	thumb.connect("requested_delete", self, "on_requested_delete", [thumb])
	thumb.connect("requested_clear", self, "on_requested_clear", [thumb])
	thumb.connect("requested_set_dialog", self, "on_set_dialog", [thumb])
	thumb.connect("requested_set_drag", self, "on_set_drag", [thumb])
	thumb.connect("requested_press", self, "on_press", [thumb])
	thumb.connect("requested_check", self, "on_check", [thumb])
	thumb.connect("requested_label_edit", self, "on_label_edit", [thumb])
	
	return thumb


# Generate an action thumbnail that creates new action thumbnails
func _generate_thumbnail_create_inst():
	var thumb := UI_ActionThumbnailCreateInst.instance()
	thumb.init(element_display_size, float(element_display_size) * 0.5, PRESET_NEW)
	thumb.connect("requested_press", self, "on_requested_add")
	
	return thumb




#-------------------------------------------------------------------------------
# Request PropActions
#-------------------------------------------------------------------------------


# Action thumbnail callback
func on_requested_add():
	pass


# Action thumbnail callback
func on_requested_delete(thumb):
	pass


# Action thumbnail callback
func on_requested_clear(thumb):
	pass


# Action thumbnail callback
func on_set_dialog(thumb):
	file_dialog.popup_centered_ratio(0.5)
	file_dialog.connect("file_selected", self, "on_file_selected", [thumb])


# Action thumbnail callback
func on_set_drag(path, thumb):
	on_file_selected(path, thumb)


# Action thumbnail callback
func on_check(state, thumb):
	pass


# Action thumbnail callback
func on_label_edit(label_text, thumb):
	pass


# Action thumbnail callback
func on_press(thumb):
	pass




#-------------------------------------------------------------------------------
# Assign/clear project files to thumbnails
#-------------------------------------------------------------------------------


func file_dialog_hidden():
	if file_dialog.is_connected("file_selected", self, "on_file_selected"):
		file_dialog.disconnect("file_selected", self, "on_file_selected")


# Load and try to assign a choosen resource
func on_file_selected(path, thumb):
	var res = load(path)
	
	var found_example = false
	for accepted_classe in accepted_classes:
		if FunLib.obj_is_class_string(res, accepted_classe):
			found_example = true
			break
	
	if !found_example:
		logger.error("Selected a wrong resource class!")
		return
	
	set_res_for_thumbnail(res, thumb)


# Request a custom prop action to set the property of an owning object
# To be overridden
func set_res_for_thumbnail(res:Resource, thumb):
	pass




#-------------------------------------------------------------------------------
# Manage thumbnails
#-------------------------------------------------------------------------------


# Queue a resource for preview generation in a resource previewer
func _queue_thumbnail(res:Resource, thumb):
	if !is_inside_tree(): return
	var resource_path = _get_resource_path_for_resource(res)
	if resource_path == "":
		thumb.set_thumbnail(null)
		if res:
			thumb.set_alt_text(res.resource_name)
	else:
		_resource_previewer.queue_resource_preview(resource_path, self, "try_assign_to_thumbnail", 
			{'thumb': thumb, 'thumb_res': res})


# Find a path to use as preview for a given resource
# TODO optimize this into a custom EditorResourcePreview
func _get_resource_path_for_resource(resource:Resource):
	match FunLib.get_obj_class_string(resource):
		"Greenhouse_PlantState":
			if resource.plant.mesh_LOD_variants.size() >= 1 && resource.plant.mesh_LOD_variants[0].mesh:
				return resource.plant.mesh_LOD_variants[0].mesh.resource_path
		"Greenhouse_LODVariant":
			if resource.mesh:
				return resource.mesh.resource_path
	if resource:
		return resource.resource_path
	else:
		return ""


# Callback to assign a thumbnail after it was generated
func try_assign_to_thumbnail(path:String, preview:Texture, thumbnail_preview:Texture, userdata: Dictionary):
	if !is_inside_tree(): return
	if preview:
		userdata.thumb.set_thumbnail(preview)
	else:
		var alt_name = path.get_file()
		if userdata.thumb_res:
			alt_name = userdata.thumb_res.resource_name
		userdata.thumb.set_alt_text(alt_name)
