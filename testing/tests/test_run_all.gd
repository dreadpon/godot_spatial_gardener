@tool
extends "test_base.gd"


var execution_list:Array = []
var result_list:Array = []




func execute():
	super.execute()
	
	logger.info("Executing all plant tests")
	result_list = []
	
	for child in get_children():
		if child.has_method("execute"):
			execution_list.append(child)
	
	execute_next_test()


func execute_next_test():
	execution_list[0].finished_execution.connect(test_execution_finished)
	execution_list[0].execute()


func test_execution_finished(results:Array = []):
	result_list.append_array(results)
	
	execution_list[0].finished_execution.disconnect(test_execution_finished)
	execution_list.pop_front()
	if !execution_list.is_empty():
		execute_next_test()
		return
	
	print("\n")
	logger.info("All plant test results:")
	for result in result_list:
		match result.severity:
			0:
				result.logger.info(result.text)
			1:
				result.logger.info(result.text)
			2:
				result.logger.error(result.text)
	finish_execution()


func _unhandled_key_input(event):
	if event.pressed:
		Node.print_orphan_nodes()
