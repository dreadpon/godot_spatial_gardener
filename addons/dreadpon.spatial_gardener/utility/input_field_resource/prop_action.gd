tool
extends Reference


#-------------------------------------------------------------------------------
# A base storage object for actions that affect properties in some way
#-------------------------------------------------------------------------------


var prop:String = ""
var val = null
var can_create_history:bool




func _init(__prop:String, __val):
	set_meta("class", "PropAction")
	
	prop = __prop
	val = __val
	can_create_history = true


func _to_string():
	return "%s: [prop: %s, val: %s, can_create_history: %s]" % [get_meta("class"), prop, str(val), str(can_create_history)]


func duplicate(deep:bool = false):
	var copy = self.get_script().new(prop, val)
	copy.can_create_history = can_create_history
	
	if deep:
		if copy.val is Array || copy.val is Dictionary:
			copy.val = copy.val.duplicate()
	
	return copy
