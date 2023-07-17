@tool
extends Node3D

@export var do_stuff = false : set = _set_do_stuff


func _set_do_stuff(val):
	do_stuff = false
	if val:
		var counter = 0
		var array = range(0, 1_000_000)
		
		var start = Time.get_ticks_msec()
		for i in array:
			if i < 500_000:
				counter += 1
		print(Time.get_ticks_msec() - start)
		
		start = Time.get_ticks_msec()
		array = array.filter(filter)
		for i in array:
			counter += 1
		print(Time.get_ticks_msec() - start)



func filter(element):
	return element < 500_000
