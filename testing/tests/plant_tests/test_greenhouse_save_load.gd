@tool
extends "test_plant_base.gd"


const GreenhouseSaveLoadNode = preload("../../utility/greenhouse_save_load_node.gd")


@export var test_save_load_path:String = "" # (String, DIR)




func execute():
	super.execute()
	
	var greenhouses := load_greenhouses()
	
	var loads_gone_wrong := 0
	logger.info("Executing test for '%d' greenhouses\n" % [greenhouses.size()])
	
	var greenhouse_save_load_node:GreenhouseSaveLoadNode
	for i in range(0, greenhouses.size()):
		var greenhouse:Greenhouse = greenhouses[i]
		var last_greenhouse:Greenhouse = null
		if i > 0:
			last_greenhouse = greenhouses[i-1]
		
		greenhouse_save_load_node = GreenhouseSaveLoadNode.new()
		add_child(greenhouse_save_load_node)
		
		if i > 0:
			greenhouse_save_load_node.load_from_path(test_save_load_path, "greenhouse.tres")
			
			if find_discrepancies(-1, last_greenhouse, greenhouse_save_load_node.greenhouse, "during load of '%d'" % [i-1]):
				loads_gone_wrong += 1
		
		greenhouse_save_load_node.save_given(greenhouse.duplicate_ifr(false, true), test_save_load_path, "greenhouse.tres")
		remove_child(greenhouse_save_load_node)
		greenhouse_save_load_node.queue_free()
	
	var results = print_and_get_result(-1, {"load discrepancies": loads_gone_wrong})
	finish_execution(results)
