tool


#-------------------------------------------------------------------------------
# A modifed version of Zylann's "logger.gd" from "zylann.hterrain" plugin
# Guidelines for printing errors:
	# assert() - a built-in for terminal failures. Only works in debug builds/editor
	# logger.debug() - nuanced logging when engine was launched with "-v" (verbose stdout)
	# logger.info() - important info/notes for the user to keep in mind
	# logger.warn() - something isn't excatly by the book, but we allow it/can work around it
	# logger.error() - something is wrong and current task will fail. Has to be corrected to continue normal use
#-------------------------------------------------------------------------------


# A Base Logger type
class Base:
	var _context := ""
	
	func _init(__context:String):
		_context = __context
	
#	func debug(msg:String):
#		pass
	
	func info(msg):
		print("INFO: {0}: {1}".format([_context, str(msg)]))
	
	func warn(msg):
		push_warning("{0}: {1}".format([_context, str(msg)]))
	
	func error(msg):
		push_error("{0}: {1}".format([_context, str(msg)]))


# A Verbose Logger type
# Meant to display verbose debug messages
#class Verbose extends Base:
#	func _init(__context:String).(__context):
#		pass
#
#	func debug(msg:String):
#		print("DEBUG: {0}: {1}".format([_context, msg]))




# As opposed to original, for now we don't have separate "Verbose" logging
# Instead we use ProjectSettings to toggle frequently used logging domains
static func get_for(owner:Object, name:String = "") -> Base:
	# Note: don't store the owner. If it's a Reference, it could create a cycle
	var context = owner.get_script().resource_path.get_file()
	if name != "":
		context += " (%s)" % [name]
	return get_for_string(context)


# Get logger with a string context
static func get_for_string(context:String) -> Base:
#	if OS.is_stdout_verbose():
#		return Verbose.new(string_context)
	return Base.new(context)
