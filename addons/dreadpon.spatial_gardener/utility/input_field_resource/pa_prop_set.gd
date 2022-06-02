tool
extends "prop_action.gd"


#-------------------------------------------------------------------------------
# Set a property
#-------------------------------------------------------------------------------




func _init(__prop:String, __val).(__prop, __val):
	set_meta("class", "PA_PropSet")
	can_create_history = true


func _to_string():
	return "%s: [prop: %s, val: %s, can_create_history: %s]" % [get_meta("class"), prop, str(val), str(can_create_history)]
