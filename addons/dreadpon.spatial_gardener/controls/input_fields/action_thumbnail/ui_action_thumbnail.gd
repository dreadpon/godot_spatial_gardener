tool
extends Control


#-------------------------------------------------------------------------------
# A button with multiple children buttons corresponding to various possible interactions
# It's main purpose is to display a thumbnail and respond to UI inputs
#-------------------------------------------------------------------------------


const ThemeAdapter = preload("../../theme_adapter.gd")


# These flags define what sort of signals and broadcast
enum InteractionFlags {DELETE, SET_DIALOG, SET_DRAG, EDIT_DIALOG, PRESS, CHECK, CLEAR, SHOW_COUNT}


var active_interaction_flags:Array = [] setget set_active_interaction_flags
export var thumb_size:int = 100 setget set_thumb_size
export var button_size:int = 32 setget set_button_size

var root_button_nd:Control = null
var texture_rect_nd:Control = null
var selection_panel_nd:Control = null
var check_box_nd:Control = null
var clear_button_nd:Control = null
var delete_button_nd:Control = null
var counter_container_nd:Control = null
var counter_label_nd:Control = null

var alt_text_margin_nd:Control = null
var alt_text_label_nd:Control = null


signal requested_delete
signal requested_set_dialog
signal requested_set_drag
signal requested_press
signal requested_check
signal requested_clear




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func init(_thumb_size:int, _button_size:int, _active_interaction_flags:Array):
	set_meta("class", "UI_ActionThumbnail")
	thumb_size = _thumb_size
	button_size = _button_size
	active_interaction_flags = _active_interaction_flags.duplicate()


# We have some conditional checks here
# Because inheriting nodes might ditch some of the functionality
func _ready():
	if has_node("RootButton"):
		root_button_nd = $RootButton
		if root_button_nd.has_signal("dropped"):
			root_button_nd.connect("dropped", self, "on_set_drag")
		root_button_nd.connect("pressed", self, "on_set_dialog")
		root_button_nd.connect("pressed", self, "on_press")
	if has_node("TextureRect"):
		texture_rect_nd = $TextureRect
	if has_node("SelectionPanel"):
		selection_panel_nd = $SelectionPanel
		selection_panel_nd.visible = false
	if has_node("CheckBox"):
		check_box_nd = $CheckBox
		check_box_nd.connect("pressed", self, "on_check")
	if has_node("ClearButton"):
		clear_button_nd = $ClearButton
		clear_button_nd.connect("pressed", self, "on_clear")
	if has_node("DeleteButton"):
		delete_button_nd = $DeleteButton
		delete_button_nd.connect("pressed", self, "on_delete")
	if has_node("CounterContainer"):
		counter_container_nd = $CounterContainer
		if has_node("CounterContainer/CounterLabel"):
			counter_label_nd = $CounterContainer/CounterLabel
	if has_node("AltTextMargin"):
		alt_text_margin_nd = $AltTextMargin
		ThemeAdapter.assign_node_type(alt_text_margin_nd, "ExternalMargin")
	if has_node("AltTextMargin/AltTextLabel"):
		alt_text_label_nd = $AltTextMargin/AltTextLabel
	
	update_size()
	set_active_interaction_flags(active_interaction_flags)




#-------------------------------------------------------------------------------
# Resizing
#-------------------------------------------------------------------------------


func set_thumb_size(val:int):
	thumb_size = val
	update_size()

func set_button_size(val:int):
	button_size = val
	update_size()


func update_size():
	if !is_inside_tree(): return
	
	var thumb_rect = Vector2(thumb_size, thumb_size)
	
	set_size(thumb_rect)
	visible = false
	
	# I don't know why I need both this and the same thing in the update_size_step2()
	# As well as why I need to set min_rect to 1 beforehand
	# But it seems to break otherwise
	# Control size updating seems a bit broken in general, or just way too convoluted to define a clear set of rules :/
	rect_min_size = Vector2.ONE
	rect_size = thumb_rect
	rect_min_size = thumb_rect
	
	call_deferred("update_size_step2")


func update_size_step2():
	var thumb_rect = Vector2(thumb_size, thumb_size)
	var button_rect = Vector2(button_size, button_size)
	var toMargin = thumb_size - button_size - 4
	
	root_button_nd.set_size(thumb_rect)
	texture_rect_nd.set_size(thumb_rect)
	
	if is_instance_valid(selection_panel_nd):
		selection_panel_nd.set_size(thumb_rect)
	
	if is_instance_valid(check_box_nd):
		check_box_nd.get_icon("checked").set_size_override(button_rect)
		check_box_nd.get_icon("unchecked").set_size_override(button_rect)
		check_box_nd.set_size(button_rect)
		check_box_nd.set_position(Vector2(4, toMargin))
	if is_instance_valid(clear_button_nd):
		clear_button_nd.set_size(button_rect)
		clear_button_nd.set_position(Vector2(4, 4))
	if is_instance_valid(delete_button_nd):
		delete_button_nd.set_size(button_rect)
		delete_button_nd.set_position(Vector2(toMargin, 4))
	if is_instance_valid(counter_container_nd):
		counter_container_nd.set_size(button_rect)
		counter_container_nd.set_position(Vector2(toMargin, toMargin))
		
		counter_label_nd.rect_pivot_offset = counter_label_nd.rect_size
		var scale = float(button_size) / 32.0
		counter_label_nd.rect_scale = Vector2(scale, scale)
	
	rect_size = thumb_rect
	rect_min_size = thumb_rect
	visible = true


func set_counter_val(val:int):
	counter_label_nd.text = str(val)
	




#-------------------------------------------------------------------------------
# Interaction flags
#-------------------------------------------------------------------------------


func set_active_interaction_flags(flags:Array):
	var ownFlagsCopy = active_interaction_flags.duplicate()
	var flagsCopy = flags.duplicate()
	
	for flag in ownFlagsCopy:
		set_interaction_flag(flag, false)
	for flag in flagsCopy:
		set_interaction_flag(flag, true)


func set_interaction_flag(flag:int, state:bool):
	if state:
		if !active_interaction_flags.has(flag):
			active_interaction_flags.append(flag)
	else:
		active_interaction_flags.erase(flag)

	enable_features_to_flag(flag, state)


func enable_features_to_flag(flag:int, state:bool):
	if is_inside_tree():
		match flag:
			InteractionFlags.DELETE:
				delete_button_nd.visible = state
			InteractionFlags.CHECK:
				check_box_nd.visible = state
			InteractionFlags.CLEAR:
				clear_button_nd.visible = state
			InteractionFlags.SHOW_COUNT:
				counter_container_nd.visible = state


func set_features_val_to_flag(flag:int, val):
	if is_inside_tree():
		match flag:
			InteractionFlags.PRESS:
				selection_panel_nd.visible = val
			InteractionFlags.CHECK:
				check_box_nd.pressed = val


func on_delete():
	if active_interaction_flags.has(InteractionFlags.DELETE):
		emit_signal("requested_delete")

func on_set_dialog():
	if active_interaction_flags.has(InteractionFlags.SET_DIALOG):
		emit_signal("requested_set_dialog")

func on_set_drag(path):
	if active_interaction_flags.has(InteractionFlags.SET_DRAG):
		emit_signal("requested_set_drag", path)

func on_press():
	if active_interaction_flags.has(InteractionFlags.PRESS):
		emit_signal("requested_press")

func on_check():
	if active_interaction_flags.has(InteractionFlags.CHECK):
		emit_signal("requested_check", check_box_nd.pressed)

func on_clear():
	if active_interaction_flags.has(InteractionFlags.CLEAR):
		emit_signal("requested_clear")




#-------------------------------------------------------------------------------
# Thumbnail itself and other visuals
#-------------------------------------------------------------------------------


func set_thumbnail(texture:Texture):
	texture_rect_nd.visible = true
	alt_text_label_nd.visible = false
	
	texture_rect_nd.texture = texture
	alt_text_label_nd.text = ""


func set_alt_text(alt_text:String):
	alt_text_label_nd.visible = true
	texture_rect_nd.visible = false
	
	alt_text_label_nd.text = alt_text
	texture_rect_nd.texture = null
