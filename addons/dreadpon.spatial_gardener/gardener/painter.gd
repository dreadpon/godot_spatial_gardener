tool
extends Reference


#-------------------------------------------------------------------------------
# Handles keeping track of brush strokes, brush position and some of the brush settings
# Also notifies others of painting lifecycle updates
#-------------------------------------------------------------------------------


const FunLib = preload("../utility/fun_lib.gd")
const Toolshed_Brush = preload("../toolshed/toolshed_brush.gd")
const Globals = preload("../utility/globals.gd")


enum ModifierKeyList {KEY_SHIFT, KEY_CONTROL, KEY_ALT, KEY_TAB}
enum BrushPrimaryKeyList {BUTTON_LEFT, BUTTON_RIGHT, BUTTON_MIDDLE, BUTTON_XBUTTON1, BUTTON_XBUTTON2}
enum BrushPropEditFlag {MODIFIER, NONE, SIZE, STRENGTH}


var owned_spatial:Spatial = null

const brush_material = preload("../shaders/shm_brush.tres")
var paint_brush_node:MeshInstance = null
var can_draw:bool = false

var brush_prop_edit_flag = BrushPropEditFlag.NONE
const brush_prop_edit_max_dist:float = 500.0
var brush_prop_edit_max_val:float = 0.0
var brush_prop_edit_cur_val:float = 0.0
var brush_prop_edit_start_pos:Vector2 = Vector2.ZERO
var brush_prop_edit_offset:float = 0.0

var is_drawing:bool = false
var brush_collision_mask:int setget set_brush_collision_mask

# This bunch here is to sync quick brush property edit with UI and vice-versa
var pending_draw:bool = false
var active_brush_data:Dictionary = {}
var active_brush_size:float setget set_active_brush_size
var active_brush_strength:float setget set_active_brush_strength
var active_brush_max_size:float setget set_active_brush_max_size
var active_brush_max_strength:float setget set_active_brush_max_strength


signal changed_active_brush_size(val, final)
signal changed_active_brush_strength(val, final)

signal stroke_started
signal stroke_finished
signal stroke_updated




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


# When working with this object, we assume it does not exist outside the editor
func _init(_owned_spatial):
	set_meta("class", "Painter")
	
	owned_spatial = _owned_spatial
	
	paint_brush_node = MeshInstance.new()
	paint_brush_node.name = "active_brush"
	paint_brush_node.mesh = SphereMesh.new()
	paint_brush_node.mesh.radial_segments = 32
	paint_brush_node.mesh.rings = 16
	paint_brush_node.cast_shadow = false
	paint_brush_node.material_override = brush_material.duplicate()
	
	owned_spatial.add_child(paint_brush_node)
	set_can_draw(false)


func update(delta):
	consume_pending_draw(delta)




#-------------------------------------------------------------------------------
# Editing lifecycle
#-------------------------------------------------------------------------------


func start_editing():
	set_can_draw(true)


func stop_editing():
	stop_brush_stroke()
	set_can_draw(false)




#-------------------------------------------------------------------------------
# Input
#-------------------------------------------------------------------------------


func forwarded_input(camera:Camera, event):
	if !can_draw: return
	
	var handled = false
	
	# If inactive property edit 
	# And event == mouseMotion
	# -> move the brush
	if brush_prop_edit_flag <= BrushPropEditFlag.NONE:
		if event is InputEventMouseMotion:
			move_brush(camera, event)
			# Don't handle input - it's not destructive
	
	# If inactive property edit/modifier key pressed
	# And event == modifier key pressed
	# -> remember/forget the modifier
	if brush_prop_edit_flag <= BrushPropEditFlag.NONE && event is InputEventKey && event.scancode == get_property_edit_modifier_key():
		if event.pressed:
			brush_prop_edit_flag = BrushPropEditFlag.MODIFIER
		if !event.pressed:
			brush_prop_edit_flag = BrushPropEditFlag.NONE
		handled = true
	
	# If inactive property edit or modifier key pressed 
	# And event == property edit trigger pressed
	# -> start property edit
	if brush_prop_edit_flag <= BrushPropEditFlag.NONE && event is InputEventMouseButton && event.button_index == get_property_edit_button():
		if event.pressed:
			brush_prop_edit_flag = BrushPropEditFlag.SIZE if brush_prop_edit_flag != BrushPropEditFlag.MODIFIER else BrushPropEditFlag.STRENGTH
			start_brush_prop_edit(event.global_position)
			handled = true
	
	# If editing property
	# And event == property edit trigger released
	# -> stop property edit
	if brush_prop_edit_flag > BrushPropEditFlag.NONE && event is InputEventMouseButton && event.button_index == get_property_edit_button():
		if !event.pressed:
			finish_brush_prop_edit(camera)
			brush_prop_edit_flag = BrushPropEditFlag.NONE
			handled = true
	
	# If editing property
	# And event == mouseMotion
	# -> update property value
	if brush_prop_edit_flag > BrushPropEditFlag.NONE && event is InputEventMouseMotion:
		brush_prop_edit_calc_val(event.global_position)
		handled = true
	
	# If editing property
	# And event == paint trigger pressed/releasedq
	# -> start/stop the brush stroke
	if brush_prop_edit_flag == BrushPropEditFlag.NONE && event is InputEventMouseButton && event.button_index == BUTTON_LEFT:
		if event.pressed:
			move_brush(camera, event)
			start_brush_stroke()
		else:
			stop_brush_stroke()
		handled = true
	
	return handled


func get_property_edit_modifier_key():
	# This convolution exists because a project setting with default value is not saved for some reason and load as "null"
	# See https://github.com/godotengine/godot/issues/56598
	var key = FunLib.get_setting_safe("dreadpon_spatial_gardener/input_and_ui/brush_property_edit_modifier_key", Globals.KeyList.KEY_SHIFT)
	return Globals.index_to_enum(key, Globals.KeyList)


func get_property_edit_button():
	var key = FunLib.get_setting_safe("dreadpon_spatial_gardener/input_and_ui/brush_property_edit_button", Globals.ButtonList.BUTTON_RIGHT)
	return Globals.index_to_enum(key, Globals.ButtonList)




#-------------------------------------------------------------------------------
# Painting lifecycle and brush movement
#-------------------------------------------------------------------------------


func set_can_draw(state):
	can_draw = state
	if state:
		paint_brush_node.visible = true
	else:
		paint_brush_node.visible = false


func start_brush_stroke():
	if is_drawing: return
	is_drawing = true
	emit_signal("stroke_started", active_brush_data)


func stop_brush_stroke():
	if !is_drawing: return
	is_drawing = false
	active_brush_data = {}
	emit_signal("stroke_finished", active_brush_data)


# Actually update the stroke only if it was preceeded by the input event
func consume_pending_draw(delta):
	if !can_draw: return
	if !is_drawing: return
	if !pending_draw: return
	
	pending_draw = false
	emit_signal("stroke_updated", active_brush_data)


func move_brush(camera:Camera, event):
	var space_state = camera.get_world().direct_space_state
	var start = camera.project_ray_origin(event.position)
	var end = start + camera.project_ray_normal(event.position) * camera.far
	raycast_brush_data(space_state, start, end)


func raycast_brush_data(space_state:PhysicsDirectSpaceState, start:Vector3, end:Vector3):
	var ray_result:Dictionary = space_state.intersect_ray(start, end, [], brush_collision_mask)
	if !ray_result.empty():
		update_active_brush_data(ray_result.position, ray_result.normal)


func update_active_brush_data(position:Vector3, normal:Vector3):
	paint_brush_node.global_transform.origin = position
	active_brush_data.brush_normal = normal
	active_brush_data.brush_pos = position
	pending_draw = true





#-------------------------------------------------------------------------------
# Quick brush property edit lifecycle
#-------------------------------------------------------------------------------


# Quickly edit a brush property without using the UI (aka like in Blender)
# The flow here is as follows:
# 1. Respond to mouse events, calculate property value, emit a signal
# 2. Signal is received in the Gardener, passed to an active Toolshed_Brush
# 3. Active brush updates it's values
# 4. Toolshed notifies Painter of a value change
# 5. Painter updates it's helper variables and visual representation

# Set the initial value of edited property and mouse offset
func start_brush_prop_edit(mouse_pos):
	match brush_prop_edit_flag:
		BrushPropEditFlag.SIZE:
			brush_prop_edit_cur_val = active_brush_size
			brush_prop_edit_max_val = active_brush_max_size
		BrushPropEditFlag.STRENGTH:
			brush_prop_edit_cur_val = active_brush_strength
			brush_prop_edit_max_val = active_brush_max_strength
	
	brush_prop_edit_start_pos = mouse_pos
	brush_prop_edit_offset = brush_prop_edit_cur_val / brush_prop_edit_max_val * brush_prop_edit_max_dist


# Calculate edited property value based on mouse offset
func brush_prop_edit_calc_val(mouse_pos):
	brush_prop_edit_cur_val = clamp((mouse_pos.x - brush_prop_edit_start_pos.x + brush_prop_edit_offset) / brush_prop_edit_max_dist, 0.0, 1.0) * brush_prop_edit_max_val
	
	match brush_prop_edit_flag:
		BrushPropEditFlag.SIZE:
			emit_signal("changed_active_brush_size", brush_prop_edit_cur_val, false)
		BrushPropEditFlag.STRENGTH:
			emit_signal("changed_active_brush_strength", brush_prop_edit_cur_val, false)


# Stop editing brush property and reset helper variables and mouse position
func finish_brush_prop_edit(camera:Camera):
	match brush_prop_edit_flag:
		BrushPropEditFlag.SIZE:
			emit_signal("changed_active_brush_size", brush_prop_edit_cur_val, true)
		BrushPropEditFlag.STRENGTH:
			emit_signal("changed_active_brush_strength", brush_prop_edit_cur_val, true)
	
	camera.get_viewport().warp_mouse(brush_prop_edit_start_pos)
	
	brush_prop_edit_flag = BrushPropEditFlag.NONE
	brush_prop_edit_start_pos = Vector2.ZERO
	brush_prop_edit_max_val = 0.0
	brush_prop_edit_cur_val = 0.0




#-------------------------------------------------------------------------------
# Quick brush property edit setters
#-------------------------------------------------------------------------------


# Update helper variables and visuals
func set_active_brush_size(val):
	active_brush_size = val
	paint_brush_node.material_override.set_shader_param("proximity_multiplier", active_brush_size * 0.5)
	set_brush_diameter(active_brush_size)


# Update helper variables and visuals
func set_active_brush_max_size(val):
	active_brush_max_size = val
	set_brush_diameter(active_brush_size)


# Update helper variables
func set_active_brush_strength(val):
	active_brush_strength = val


# Update helper variables
func set_active_brush_max_strength(val):
	active_brush_max_strength = val


# Update visuals
func set_brush_diameter(diameter):
	paint_brush_node.mesh.radius = diameter * 0.5
	paint_brush_node.mesh.height = diameter


func set_brush_collision_mask(val):
	brush_collision_mask = val
