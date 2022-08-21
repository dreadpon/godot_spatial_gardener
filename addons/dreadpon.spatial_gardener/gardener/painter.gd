tool
extends Reference


#-------------------------------------------------------------------------------
# Handles keeping track of brush strokes, brush position and some of the brush settings
# Also notifies others of painting lifecycle updates
#-------------------------------------------------------------------------------


const FunLib = preload("../utility/fun_lib.gd")
const DebugDraw = preload("../utility/debug_draw.gd")
const Toolshed_Brush = preload("../toolshed/toolshed_brush.gd")
const Globals = preload("../utility/globals.gd")


enum ModifierKeyList {KEY_SHIFT, KEY_CONTROL, KEY_ALT, KEY_TAB}
enum BrushPrimaryKeyList {BUTTON_LEFT, BUTTON_RIGHT, BUTTON_MIDDLE, BUTTON_XBUTTON1, BUTTON_XBUTTON2}
enum BrushPropEditFlag {MODIFIER, NONE, SIZE, STRENGTH}


var owned_spatial:Spatial = null
# Used for immediate updates when changes happen to the brush
# This should NOT be used in update() or each frame in general
var _cached_camera: Camera = null

const sphere_brush_material = preload("../shaders/shm_sphere_brush.tres")
const circle_brush_material = preload("../shaders/shm_circle_brush.tres")
var paint_brush_node:MeshInstance = null

# Temporary variables to store current quick prop edit state
var brush_prop_edit_flag = BrushPropEditFlag.NONE
const brush_prop_edit_max_dist:float = 500.0
var brush_prop_edit_max_val:float = 0.0
var brush_prop_edit_cur_val:float = 0.0
var brush_prop_edit_start_pos:Vector2 = Vector2.ZERO
var brush_prop_edit_offset:float = 0.0

var can_draw:bool = false
var is_drawing:bool = false
var pending_movement_update:bool = false
var brush_collision_mask:int setget set_brush_collision_mask

# Used to pass during stroke-state signals sent to Gardener/Arborist
# Meant to avoid retrieving transform from an actual 3D node
# And more importantly to cache a raycast normal at every given point in time
var active_brush_data:Dictionary = {'brush_pos': Vector3.ZERO, 'brush_normal': Vector3.UP, 'brush_basis': Basis()} 

# Variables to sync quick brush property edit with UI and vice-versa
# And also for keeping brush state up-to-date without needing a reference to actual active brush
var active_brush_overlap_mode: int = Toolshed_Brush.OverlapMode.VOLUME
var active_brush_size:float setget set_active_brush_size
var active_brush_strength:float setget set_active_brush_strength
var active_brush_max_size:float setget set_active_brush_max_size
var active_brush_max_strength:float setget set_active_brush_max_strength

# A queue of methods to be called once _cached_camera becomes available
var when_camera_queue: Array = []

# Ooooh boy
# Go to finish_brush_prop_edit() for explanation
var mouse_move_call_delay: int = 0


signal changed_active_brush_prop(prop, val, final)

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
	set_brush_mesh()
	
	owned_spatial.add_child(paint_brush_node)
	set_can_draw(false)


func update(delta):
	if _cached_camera:
		# Handle queue of methods that need a _cached_camera
		for queue_item in when_camera_queue.duplicate():
			callv(queue_item.method_name, queue_item.args)
			when_camera_queue.erase(queue_item)
	consume_brush_drawing_update(delta)


func set_brush_mesh(is_sphere: bool = false):
	if is_sphere:
		paint_brush_node.mesh = SphereMesh.new()
		paint_brush_node.mesh.radial_segments = 32
		paint_brush_node.mesh.rings = 16
		paint_brush_node.cast_shadow = false
		paint_brush_node.material_override = sphere_brush_material.duplicate()
	else:
		paint_brush_node.mesh = QuadMesh.new()
		paint_brush_node.cast_shadow = false
		paint_brush_node.material_override = circle_brush_material.duplicate()


# Queue a call to method that needs a _cached_camera to be set
func queue_call_when_camera(method_name: String, args: Array = []):
	when_camera_queue.append({'method_name': method_name, 'args': args})




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
	
	_cached_camera = camera
	var handled = false
	
	# If inactive property edit
	# And event == mouseMotion
	# -> move the brush
	if brush_prop_edit_flag <= BrushPropEditFlag.NONE:
		if (event is InputEventMouseMotion
			|| (event is InputEventMouseButton && event.button_index == BUTTON_WHEEL_UP)
			|| (event is InputEventMouseButton && event.button_index == BUTTON_WHEEL_DOWN)):
			
			if mouse_move_call_delay > 0:
				mouse_move_call_delay -= 1
			else:
				move_brush()
				pending_movement_update = true
			# Don't handle input - moving a brush is not destructive
	
	# If inactive property edit
	# And event == overlap mode key
	# -> cycle overlap modes
	if brush_prop_edit_flag <= BrushPropEditFlag.NONE && event is InputEventKey && event.scancode == get_overlap_mode_key():
		if event.pressed && !event.is_echo():
			cycle_overlap_modes()
		handled = true
	
	# If inactive property edit/modifier key pressed
	# And event == modifier key pressed
	# -> remember/forget the modifier
	if brush_prop_edit_flag <= BrushPropEditFlag.NONE && event is InputEventKey && event.scancode == get_property_edit_modifier():
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
			move_brush()
			start_brush_stroke()
		else:
			stop_brush_stroke()
		handled = true
	
	return handled


func get_property_edit_modifier():
	# This convolution exists because a project setting with default value is not saved for some reason and load as "null"
	# See https://github.com/godotengine/godot/issues/56598
	var key = FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/brush_prop_edit_modifier", Globals.KeyList.KEY_SHIFT)
	return Globals.index_to_enum(key, Globals.KeyList)


func get_property_edit_button():
	var key = FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/brush_prop_edit_button", Globals.ButtonList.BUTTON_RIGHT)
	return Globals.index_to_enum(key, Globals.ButtonList)


func get_overlap_mode_key():
	var key = FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/brush_overlap_mode_button", Globals.KeyList.KEY_QUOTELEFT)
	return Globals.index_to_enum(key, Globals.KeyList)




#-------------------------------------------------------------------------------
# Painting lifecycle 
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
	active_brush_data = {'brush_pos': Vector3.ZERO, 'brush_normal': Vector3.UP, 'brush_basis': Basis()} 
	emit_signal("stroke_finished", active_brush_data)


# Actually update the stroke only if it was preceeded by the input event
func consume_brush_drawing_update(delta):
	if !can_draw: return
	if !is_drawing: return
	if !pending_movement_update: return
	
	pending_movement_update = false
	emit_signal("stroke_updated", active_brush_data)




#-------------------------------------------------------------------------------
# Brush movement
#-------------------------------------------------------------------------------


func move_brush():
	if !_cached_camera: return
	update_active_brush_data()
	refresh_brush_transform()


# Update brush data that is passed through signals to Gardener/Arborist
# Raycast overrides exist for compatability with gardener tests
func update_active_brush_data(raycast_overrides: Dictionary = {}):
	var space_state = paint_brush_node.get_world().direct_space_state
	var start = project_mouse_near() if !raycast_overrides.has('start') else raycast_overrides.start
	var end = project_mouse_far() if !raycast_overrides.has('end') else raycast_overrides.end
	var ray_result:Dictionary = space_state.intersect_ray(start, end, [], brush_collision_mask)
	
	if !ray_result.empty():
		active_brush_data.brush_pos = ray_result.position
		active_brush_data.brush_normal = ray_result.normal
	else:
		# If raycast failed - align to camera plane, retaining current distance to camera
		var camera_normal = -_cached_camera.global_transform.basis.z
		var planar_dist_to_camera = (active_brush_data.brush_pos - _cached_camera.global_transform.origin).dot(camera_normal)
		var brush_pos:Vector3 = project_mouse(planar_dist_to_camera)
		active_brush_data.brush_pos = brush_pos
	
	# It's possible we don't have _cached_camera defined here since 
	# Gardener tests might call update_active_brush_data() without setting it
	if _cached_camera:
		# Cache to use with Projection brush
		active_brush_data.brush_basis = _cached_camera.global_transform.basis


# Update transform of a paint brush 3D node
func refresh_brush_transform():
	if active_brush_data.empty(): return
	
	match active_brush_overlap_mode:
		Toolshed_Brush.OverlapMode.VOLUME:
			paint_brush_node.global_transform.origin = active_brush_data.brush_pos
			paint_brush_node.global_transform.basis = Basis()
		Toolshed_Brush.OverlapMode.PROJECTION:
			paint_brush_node.global_transform.origin = active_brush_data.brush_pos
			paint_brush_node.global_transform.basis = active_brush_data.brush_basis
			# Projection brush size is in viewport-space, but it will move forward and backward
			# Thus appearing smaller or bigger
			# So we need to update it's size to keep it consistent
			set_brush_diameter(active_brush_size)




#-------------------------------------------------------------------------------
# Brush quick property edit lifecycle
#-------------------------------------------------------------------------------


# Quickly edit a brush property without using the UI (aka like in Blender)
# The flow here is as follows:
# 1. Respond to mouse events, calculate property value, emit a signal
# 2. Signal is received in the Gardener, passed to an active Toolshed_Brush
# 3. Active brush updates it's values
# 4. Toolshed notifies Painter of a value change
# 5. Painter updates it's helper variables and visual representation

# Switching between Volume/Projection brush is here too, but it's not connected to the whole Blender-like process
# It's just a hotkey handling

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
	
	match active_brush_overlap_mode:
		Toolshed_Brush.OverlapMode.VOLUME:
			match brush_prop_edit_flag:
				BrushPropEditFlag.SIZE:
					emit_signal('changed_active_brush_prop', 'shape/shape_volume_size', brush_prop_edit_cur_val, false)
				BrushPropEditFlag.STRENGTH:
					emit_signal('changed_active_brush_prop', 'behavior/behavior_strength', brush_prop_edit_cur_val, false)
		Toolshed_Brush.OverlapMode.PROJECTION:
			match brush_prop_edit_flag:
				BrushPropEditFlag.SIZE:
					emit_signal('changed_active_brush_prop', 'shape/shape_projection_size', brush_prop_edit_cur_val, false)


# Stop editing brush property and reset helper variables and mouse position
func finish_brush_prop_edit(camera:Camera):
	match active_brush_overlap_mode:
		Toolshed_Brush.OverlapMode.VOLUME:
			match brush_prop_edit_flag:
				BrushPropEditFlag.SIZE:
					emit_signal('changed_active_brush_prop', 'shape/shape_volume_size', brush_prop_edit_cur_val, true)
				BrushPropEditFlag.STRENGTH:
					emit_signal('changed_active_brush_prop', 'behavior/behavior_strength', brush_prop_edit_cur_val, true)
		Toolshed_Brush.OverlapMode.PROJECTION:
			match brush_prop_edit_flag:
				BrushPropEditFlag.SIZE:
					emit_signal('changed_active_brush_prop', 'shape/shape_projection_size', brush_prop_edit_cur_val, true)
	
	camera.get_viewport().warp_mouse(brush_prop_edit_start_pos)
	
	brush_prop_edit_flag = BrushPropEditFlag.NONE
	brush_prop_edit_start_pos = Vector2.ZERO
	brush_prop_edit_max_val = 0.0
	brush_prop_edit_cur_val = 0.0
	
	# Apparently warp_mouse() sometimes takes a few mouse motion events to actually take place
	# Sometimes it's instant, sometimes it takes 1, and sometimes 2 events (at least on my machine)
	# This leads to brush jumping to position used in prop edit and then back. Like it's on a string
	# As an workaround, we delay processing motion input for 2 events (which should be enough for 99% of cases?)
	mouse_move_call_delay = 2


# Cycle between brush overlap modes on a button press
func cycle_overlap_modes():
	active_brush_overlap_mode += 1
	if active_brush_overlap_mode > Toolshed_Brush.OverlapMode.PROJECTION: 
		active_brush_overlap_mode = Toolshed_Brush.OverlapMode.VOLUME
	emit_signal('changed_active_brush_prop', 'behavior/behavior_overlap_mode', active_brush_overlap_mode, true)




#-------------------------------------------------------------------------------
# Setters for brush parameters meant to be accessed from outside
# In response to UI inputs
#-------------------------------------------------------------------------------


func update_all_props_to_active_brush(brush: Toolshed_Brush):
	var max_size = 1.0
	var max_strength = 1.0
	var curr_size = 1.0
	var curr_strength = brush.behavior_strength
	
	match brush.behavior_overlap_mode:
		Toolshed_Brush.OverlapMode.VOLUME:
			max_size = FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/brush_volume_size_slider_max_value", 100.0)
			curr_size = brush.shape_volume_size
		Toolshed_Brush.OverlapMode.PROJECTION:
			max_size = FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/brush_projection_size_slider_max_value", 1000.0)
			curr_size = brush.shape_projection_size
	
	set_active_brush_overlap_mode(brush.behavior_overlap_mode)
	set_active_brush_max_size(max_size)
	set_active_brush_max_strength(max_strength)
	set_active_brush_size(curr_size)
	set_active_brush_strength(curr_strength)


# Update helper variables and visuals
func set_active_brush_size(val):
	active_brush_size = val
	paint_brush_node.material_override.set_shader_param("proximity_multiplier", active_brush_size * 0.5)
	queue_call_when_camera('set_brush_diameter', [active_brush_size])


# Update helper variables and visuals
func set_active_brush_max_size(val):
	active_brush_max_size = val
	queue_call_when_camera('set_brush_diameter', [active_brush_size])


# Update helper variables
func set_active_brush_strength(val):
	active_brush_strength = val


# Update helper variables
func set_active_brush_max_strength(val):
	active_brush_max_strength = val


# Update visuals
func set_brush_diameter(diameter: float):
	match active_brush_overlap_mode:
		
		Toolshed_Brush.OverlapMode.VOLUME:
			paint_brush_node.mesh.radius = diameter * 0.5
			paint_brush_node.mesh.height = diameter
		
		Toolshed_Brush.OverlapMode.PROJECTION:
			var camera_normal = -_cached_camera.global_transform.basis.z
			var planar_dist_to_camera = (active_brush_data.brush_pos - _cached_camera.global_transform.origin).dot(camera_normal)
			var circle_center:Vector3 = active_brush_data.brush_pos
			var circle_edge:Vector3
			# If we're editing props (or just finished it as indicated by 'mouse_move_call_delay')
			# Then to prevent size doubling/overflow use out brush position as mouse position
			# (Since out mouse WILL be offset due to us dragging it to the side)
			if brush_prop_edit_flag > BrushPropEditFlag.NONE || mouse_move_call_delay > 0:
				var screen_space_brush_pos = _cached_camera.unproject_position(active_brush_data.brush_pos)
				circle_edge = _cached_camera.project_position(screen_space_brush_pos + Vector2(diameter * 0.5, 0), planar_dist_to_camera)
			else:
				circle_edge = project_mouse(planar_dist_to_camera, Vector2(diameter * 0.5, 0))
			var size = (circle_edge - circle_center).length()
			paint_brush_node.mesh.size = Vector2(size, size) * 2.0


func set_brush_collision_mask(val):
	brush_collision_mask = val


# Update helper variables and visuals
func set_active_brush_overlap_mode(val):
	active_brush_overlap_mode = val
	
	match active_brush_overlap_mode:
		Toolshed_Brush.OverlapMode.VOLUME:
			set_brush_mesh(true)
		Toolshed_Brush.OverlapMode.PROJECTION:
			set_brush_mesh(false)
	
	# Since we are rebuilding the mesh here
	# It means that we need to move it in a proper position as well
	move_brush()




#-------------------------------------------------------------------------------
# Camera/raycasting methods
#-------------------------------------------------------------------------------


func project_mouse_near() -> Vector3:
	return project_mouse(_cached_camera.near)


func project_mouse_far() -> Vector3:
	return project_mouse(_cached_camera.far - 0.1)


func project_mouse(distance: float, offset: Vector2 = Vector2.ZERO) -> Vector3:
	return _cached_camera.project_position(_cached_camera.get_viewport().get_mouse_position() + offset, distance)
