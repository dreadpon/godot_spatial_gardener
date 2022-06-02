tool
extends Reference


#-------------------------------------------------------------------------------
# A storage object for changes to the octree members
# To be passed to UnroRedo or executed on the spot
# Can also generate opposite actions (provided it's set up correctly)
#-------------------------------------------------------------------------------


enum ChangeType {APPEND, ERASE, SET}

var changes:Array = []
var _opposite_changes:Array = []




func _init(__changes:Array = []):
	changes = __changes


# Add both the current and opposite changes
func add_change(change_type:int, at_index:int, new_val, old_val):
	var change:Change = Change.new(change_type, at_index, new_val, old_val)
	changes.append(change)
	_opposite_changes.append(get_opposite_change(change))


# Append second PaintingChanges non-destructively to the second object
func append_changes(painting_changes):
	for change in painting_changes.changes:
		add_change(change.change_type, change.at_index, change.new_val, change.old_val)


# Generate an opposite action
# For now it really just swaps new_val and old_val
# But I'm keeping it as-is just in case I need something more complex
func get_opposite_change(change):
	var opposite_change:Change = null
	match change.change_type:
		ChangeType.APPEND:
			opposite_change = Change.new(ChangeType.ERASE, change.at_index, change.old_val, change.new_val)
		ChangeType.ERASE:
			opposite_change = Change.new(ChangeType.APPEND, change.at_index, change.old_val, change.new_val)
		ChangeType.SET:
			opposite_change = Change.new(ChangeType.SET, change.at_index, change.old_val, change.new_val)
	
	return opposite_change


# Get all opposite changes as a new PaintingChanges object and remove them from the current one
func pop_opposite():
	var opposite = get_script().new(_opposite_changes)
	_opposite_changes = []
	return opposite


func _to_string():
	var string = "["
	for change in changes:
		string += str(change) + ","
	string.trim_suffix(",")
	string += "]"
	
	return string




#-------------------------------------------------------------------------------
# A storage object for a specific octree member change
# To be generated and stored by PaintingChanges
#-------------------------------------------------------------------------------


class Change extends Reference:

	var change_type:int = -1
	var at_index:int = -1
	var new_val = null
	var old_val = null
	
	
	func _init(_change_type:int = -1, _at_index:int = -1, _new_val = null, _old_val = null):
		change_type = _change_type
		at_index = _at_index
		new_val = _new_val
		old_val = _old_val
	
	
	func _to_string():
		return "[%d, %d, %s, %s]" % [change_type, at_index, str(new_val), str(old_val)]
