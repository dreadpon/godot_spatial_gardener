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
	var _log_filepath := ''
	
	func _init(__context:String, __log_filepath:String = ''):
		_context = __context
		_log_filepath = __log_filepath
		if !_log_filepath.empty():
			var dir = Directory.new()
			dir.make_dir_recursive(_log_filepath.get_base_dir())
			if !dir.file_exists(_log_filepath):
				var file = File.new()
				file.open(_log_filepath, File.WRITE)
				file.close()
	
#	func debug(msg:String):
#		pass
	
	func info(msg):
		msg = "{0}: {1}".format([_context, str(msg)])
		print("INFO: " + msg)
		log_to_file(msg)
	
	func warn(msg):
		msg = "{0}: {1}".format([_context, str(msg)])
		push_warning(msg)
		msg = 'WARNING: ' + msg
		print(msg)
		log_to_file(msg)
	
	func error(msg):
		msg = "{0}: {1}".format([_context, str(msg)])
		push_error(msg)
		msg = 'ERROR: ' + msg
		printerr(msg)
		log_to_file(msg)
	
	func assert_error(msg):
		msg = "{0}: {1}".format([_context, str(msg)])
		msg = 'ERROR: ' + msg
		print(msg)
		assert(msg)
		log_to_file(msg)
	
	# We need to route that through a logger manager of some kind, 
	# So we won't have to reopen File each time
	func log_to_file(msg: String):
		if _log_filepath.empty(): return
		var file = File.new()
		file.open(_log_filepath, File.READ_WRITE)
		file.seek_end()
		file.store_line(msg)
		file.close()



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
static func get_for(owner:Object, name:String = "", log_filepath: String = '') -> Base:
	# Note: don't store the owner. If it's a Reference, it could create a cycle
	var context = owner.get_script().resource_path.get_file()
	if name != "":
		context += " (%s)" % [name]
	return get_for_string(context, log_filepath)


# Get logger with a string context
static func get_for_string(context:String, log_filepath: String = '') -> Base:
#	if OS.is_stdout_verbose():
#		return Verbose.new(string_context)
	return Base.new(context, log_filepath)
