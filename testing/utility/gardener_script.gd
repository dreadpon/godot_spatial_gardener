extends Node


const PainterAction = preload("painter_action.gd")
const PaintBodyData = preload("paint_body_data.gd")
const Painter = preload("res://addons/dreadpon.spatial_gardener/gardener/painter.gd")
const BrushPlacementArea = preload("res://addons/dreadpon.spatial_gardener/arborist/brush_placement_area.gd")


enum CoverageMode {CENTER_50_PCT, CENTER_100_PCT, CENTER_MAX, SPOTTY_25_PCT, SPOTTY_50_PCT, SPOTTY_75_PCT, COVER, COVER_MAX, CLEAR}
const PRESET_STROKE_LENGTH_JITTER = [1, 3, 1, 5, 2, 10]




static func mk_script(paint_body_data:PaintBodyData, coverage_mode:int = CoverageMode.COVER,
	brush_size_range:Vector2 = Vector2.ZERO, stroke_length_list:Array = []):
	
	var script := []
	
	if coverage_mode < CoverageMode.CENTER_MAX:
		var extent_multiplier = 2.0
		match coverage_mode:
			CoverageMode.CENTER_50_PCT:
				extent_multiplier = 1.0
			CoverageMode.CENTER_100_PCT:
				extent_multiplier = 2.0
		mk_script_actions_center(script, paint_body_data, extent_multiplier)
	
	elif coverage_mode > CoverageMode.CENTER_MAX && coverage_mode < CoverageMode.COVER_MAX:
		var distance_multiplier = 1.0
		# '0.785' ~= 'PI/4' == 'by how much circle area is smaller than square area'
		# An approximation I didn't test, correct me if I'm wrong
		# If wrong and this needs a rewrite remember: quick and dirty beats exact and complicated
		match coverage_mode:
			CoverageMode.SPOTTY_25_PCT:
				distance_multiplier = 0.25 / 0.785
			CoverageMode.SPOTTY_50_PCT:
				distance_multiplier = 0.5 / 0.785
			CoverageMode.SPOTTY_75_PCT:
				distance_multiplier = 0.75 / 0.785
			CoverageMode.COVER:
				distance_multiplier = 2.0
		mk_script_actions_cover(script, paint_body_data, brush_size_range, distance_multiplier, stroke_length_list)
	
	return script


static func mk_script_actions_center(script:Array, paint_body_data:PaintBodyData, extent_multiplier:float):
	script.append(
		PainterAction.new(PainterAction.PainterActionType.SET_SIZE, paint_body_data, paint_body_data.extent * extent_multiplier))
	script.append(
		PainterAction.new(PainterAction.PainterActionType.START_STROKE))
	script.append(
		PainterAction.new(PainterAction.PainterActionType.MOVE_STROKE, paint_body_data, Vector2(0.5, 0.5)))
	script.append(
		PainterAction.new(PainterAction.PainterActionType.END_STROKE))


static func mk_script_actions_cover(script:Array, paint_body_data:PaintBodyData, brush_size_range:Vector2,
	distance_multiplier:float, stroke_length_list:Array):
	
	var brush_size_avg := (brush_size_range.x + brush_size_range.y) * 0.5
	var move_count := int(paint_body_data.extent * 2.0 / brush_size_avg * distance_multiplier)
	var move_step := 1.0 / move_count * 0.99
	var current_stroke_action := 0
	var stroke_length_index := 0
	
	script.append(
		PainterAction.new(PainterAction.PainterActionType.START_STROKE))
	for x in range(0, move_count + 1):
		for y in range(0, move_count + 1):
			var coord := Vector2(x * move_step, y * move_step) + Vector2(0.01, 0.01)
			var brush_size_alpha := float(y) /float(move_count + 1)
			var brush_size:float = lerp(brush_size_range.x, brush_size_range.y, brush_size_alpha)
			
			if !stroke_length_list.is_empty() && current_stroke_action >= stroke_length_list[stroke_length_index]:
				current_stroke_action = 0
				stroke_length_index += 1
				if stroke_length_list.size() <= stroke_length_index:
					stroke_length_index = 0
				
				script.append(
					PainterAction.new(PainterAction.PainterActionType.END_STROKE))
				script.append(
					PainterAction.new(PainterAction.PainterActionType.START_STROKE))
			
			script.append(
				PainterAction.new(PainterAction.PainterActionType.SET_SIZE, paint_body_data, brush_size))
			script.append(
				PainterAction.new(PainterAction.PainterActionType.MOVE_STROKE, paint_body_data, coord))
			current_stroke_action += 1
	
	script.append(
		PainterAction.new(PainterAction.PainterActionType.END_STROKE))




static func execute_painter_script(painter:Painter, script:Array):
	for action in script:
		execute_painter_action(painter, action)


static func execute_painter_action(painter:Painter, action:PainterAction):
	match action.action_type:
		PainterAction.PainterActionType.START_STROKE:
			painter.start_brush_stroke()
		PainterAction.PainterActionType.MOVE_STROKE:
			simulate_painter_move(painter, action.paint_body_data, action.action_value)
		PainterAction.PainterActionType.END_STROKE:
			painter.stop_brush_stroke()
		PainterAction.PainterActionType.SET_SIZE:
			painter.changed_active_brush_prop.emit('shape/shape_volume_size', action.action_value, false)


static func simulate_painter_move(painter:Painter, paint_body_data:PaintBodyData, fractional_coords:Vector2):
	fractional_coords = fractional_coords * 2.0 - Vector2.ONE
	var coord_origin = fractional_coords.x * paint_body_data.basis.x * paint_body_data.extent + fractional_coords.y * paint_body_data.basis.z * paint_body_data.extent
	coord_origin += paint_body_data.origin
	
	var start = coord_origin + paint_body_data.basis.y * 100.0
	var end = coord_origin - paint_body_data.basis.y * 100.0
	painter.update_active_brush_data({'start': start, 'end': end})
	painter.pending_movement_update = true




static func get_member_count_for_painting_data(painting_data:Array, plant_density:float, brush_strength:float = 1.0, coverage_modes:Array = []) -> int:
	var count := 0
	
	for i in range(0, painting_data.size()):
		var paint_body_data:PaintBodyData = painting_data[i]
		var coverage_mode:int = CoverageMode.COVER
		if coverage_modes.size() > i:
			coverage_mode = coverage_modes[i]
		
		count += get_member_count_for_paint_body(paint_body_data, plant_density, brush_strength, coverage_mode)
	
	return count


static func get_member_count_for_paint_body(paint_body_data:PaintBodyData, plant_density:float, brush_strength:float, coverage_mode:int) -> int:
	var count := 0
	
	var brush_placement_area := BrushPlacementArea.new(paint_body_data.origin, paint_body_data.extent, paint_body_data.basis.y, 0.0)
	match coverage_mode:
			CoverageMode.SPOTTY_25_PCT, CoverageMode.SPOTTY_50_PCT, CoverageMode.SPOTTY_75_PCT, CoverageMode.COVER:
				brush_placement_area.init_grid_data(plant_density, brush_strength)
				count += pow(brush_placement_area.grid_linear_size, 2)
			CoverageMode.CENTER_50_PCT, CoverageMode.CENTER_100_PCT:
				brush_placement_area.init_grid_data(plant_density, brush_strength)
				count += brush_placement_area.max_placements_allowed
			CoverageMode.CLEAR:
				count = 0
	return count
