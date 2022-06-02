tool
extends "prop_action.gd"


#-------------------------------------------------------------------------------
# Insert an array element at index
#-------------------------------------------------------------------------------




var index:int = -1




func _init(__prop:String, __val, __index:int).(__prop, __val):
	set_meta("class", "PA_ArrayInsert")
	
	index = __index
	can_create_history = true


func _to_string():
	return "%s: [prop: %s, val: %s, index: %d, can_create_history: %s]" % [get_meta("class"), prop, str(val), index, str(can_create_history)]


func duplicate(deep:bool = false):
	var copy = self.get_script().new(prop, val, index)
	copy.can_create_history = can_create_history
	return copy
