tool
extends Reference

enum PainterActionType {START_STROKE, MOVE_STROKE, END_STROKE, SET_SIZE}


var action_type:int = PainterActionType.MOVE_STROKE
var paint_body_data = null
var action_value = null




func _init(_action_type:int = PainterActionType.MOVE_STROKE, _paint_body_data = null, _action_value = null):
	action_type = _action_type
	paint_body_data = _paint_body_data
	action_value = _action_value


func _to_string():
	return "[action_type: %d, paint_body_data: %s, action_value: %s]" % [action_type, str(paint_body_data), str(action_value)]
