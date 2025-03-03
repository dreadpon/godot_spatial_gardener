#-------------------------------------------------------------------------------
# An interface for common functionality between 
# Editor-specific and runtime UndoRedo systems
#-------------------------------------------------------------------------------

extends Object


static func clear_history(undo_redo):
	if DPON_FM.is_instance_of_ed(undo_redo, "EditorUndoRedoManager"):
		push_error("Unable to clear history on EditorUndoRedoManager!")
	else:
		undo_redo.clear_history()


static func create_action(undo_redo, name: String, merge_mode := 0, backward_undo_ops := false, custom_context: Object = null):
	if DPON_FM.is_instance_of_ed(undo_redo, "EditorUndoRedoManager"):
		undo_redo.create_action(name, merge_mode, custom_context, backward_undo_ops)
	else:
		undo_redo.create_action(name, merge_mode, backward_undo_ops)


static func add_do_method(undo_redo, callable: Callable):
	if DPON_FM.is_instance_of_ed(undo_redo, "EditorUndoRedoManager"):
		var bound_args = callable.get_bound_arguments()
		match bound_args.size():
			0: undo_redo.add_do_method(callable.get_object(), callable.get_method())
			1: undo_redo.add_do_method(callable.get_object(), callable.get_method(), bound_args[0])
			2: undo_redo.add_do_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1])
			3: undo_redo.add_do_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2])
			4: undo_redo.add_do_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2], bound_args[3])
			5: undo_redo.add_do_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2], bound_args[3], bound_args[4])
			6: undo_redo.add_do_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2], bound_args[3], bound_args[4], bound_args[5])
			7: undo_redo.add_do_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2], bound_args[3], bound_args[4], bound_args[5], bound_args[6])
			8: undo_redo.add_do_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2], bound_args[3], bound_args[4], bound_args[5], bound_args[6], bound_args[7])
			9: undo_redo.add_do_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2], bound_args[3], bound_args[4], bound_args[5], bound_args[6], bound_args[7], bound_args[8])
			10: undo_redo.add_do_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2], bound_args[3], bound_args[4], bound_args[5], bound_args[6], bound_args[7], bound_args[8], bound_args[9])
			_: push_error("Too many arguments!")
	else:
		undo_redo.add_do_method(callable)


static func add_undo_method(undo_redo, callable: Callable):
	if DPON_FM.is_instance_of_ed(undo_redo, "EditorUndoRedoManager"):
		var bound_args = callable.get_bound_arguments()
		match bound_args.size():
			0: undo_redo.add_undo_method(callable.get_object(), callable.get_method())
			1: undo_redo.add_undo_method(callable.get_object(), callable.get_method(), bound_args[0])
			2: undo_redo.add_undo_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1])
			3: undo_redo.add_undo_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2])
			4: undo_redo.add_undo_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2], bound_args[3])
			5: undo_redo.add_undo_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2], bound_args[3], bound_args[4])
			6: undo_redo.add_undo_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2], bound_args[3], bound_args[4], bound_args[5])
			7: undo_redo.add_undo_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2], bound_args[3], bound_args[4], bound_args[5], bound_args[6])
			8: undo_redo.add_undo_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2], bound_args[3], bound_args[4], bound_args[5], bound_args[6], bound_args[7])
			9: undo_redo.add_undo_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2], bound_args[3], bound_args[4], bound_args[5], bound_args[6], bound_args[7], bound_args[8])
			10: undo_redo.add_undo_method(callable.get_object(), callable.get_method(), bound_args[0], bound_args[1], bound_args[2], bound_args[3], bound_args[4], bound_args[5], bound_args[6], bound_args[7], bound_args[8], bound_args[9])
			_: push_error("Too many arguments!")
	else:
		undo_redo.add_undo_method(callable)


static func add_do_reference(undo_redo, object: Object):
	undo_redo.add_do_reference(object)


static func add_undo_reference(undo_redo, object: Object):
	undo_redo.add_undo_reference(object)



static func commit_action(undo_redo, execute := true):
	undo_redo.commit_action(execute)


static func undo(undo_redo, custom_context: Object = null):
	if DPON_FM.is_instance_of_ed(undo_redo, "EditorUndoRedoManager"):
		undo_redo = undo_redo.get_history_undo_redo(undo_redo.get_object_history_id(custom_context))
	
	return undo_redo.undo()


static func redo(undo_redo, custom_context: Object = null):
	if DPON_FM.is_instance_of_ed(undo_redo, "EditorUndoRedoManager"):
		undo_redo = undo_redo.get_history_undo_redo(undo_redo.get_object_history_id(custom_context))
	
	return undo_redo.redo()


static func get_current_action_name(undo_redo, custom_context: Object = null):
	if DPON_FM.is_instance_of_ed(undo_redo, "EditorUndoRedoManager"):
		undo_redo = undo_redo.get_history_undo_redo(undo_redo.get_object_history_id(custom_context))
	
	return undo_redo.get_current_action_name()
