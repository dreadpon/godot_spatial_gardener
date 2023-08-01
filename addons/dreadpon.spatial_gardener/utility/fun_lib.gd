@tool


#-------------------------------------------------------------------------------
# A miscellaneous FUNction LIBrary
#-------------------------------------------------------------------------------


const Logger = preload("logger.gd")
const Globals = preload("globals.gd")
enum TimeTrimMode {NONE, EXACT, EXTRA_ONE, KEEP_ONE, KEEP_TWO, KEEP_THREE}




#-------------------------------------------------------------------------------
# Nodes
#-------------------------------------------------------------------------------


# Remove all children from node and free them
static func free_children(node):
	if !is_instance_valid(node): return
	for child in node.get_children().duplicate():
		node.remove_child(child)
		child.queue_free()


# Remove all children from node
static func remove_children(node):
	if !is_instance_valid(node): return
	for child in node.get_children().duplicate():
		node.remove_child(child)


# A shorthand for checking/connecting a signal
# Kinda wish Godot had a built-in one
static func ensure_signal(_signal:Signal, callable: Callable, binds:Array = [], flags:int = 0):
	if !_signal.is_connected(callable):
		_signal.connect(callable.bindv(binds), flags)


static func disconnect_all(_signal: Signal):
	for connection_data in _signal.get_connections():
		connection_data["signal"].disconnect(connection_data.callable)




#-------------------------------------------------------------------------------
# Strings
#-------------------------------------------------------------------------------


# Capitalize all strings in an array
static func capitalize_string_array(array:Array):
	var narray = array.duplicate()
	for i in range(0, narray.size()):
		if narray[i] is String:
			narray[i] = narray[i].capitalize()
	return narray


# Build a property hint_string out of strings in an array
static func make_hint_string(array:Array):
	var string = ""
	for i in range(0, array.size()):
		if array[i] is String:
			string += array[i]
		if i < array.size() - 1:
			string += ","
	return string


# Convert to custom string format, context-dependent but independednt to changes to Godot's var_to_str
static func vec3_to_str(val: Vector3) -> String:
	return "%f, %f, %f" % [val.x, val.y, val.z]


# Convert to custom string format, context-dependent but independednt to changes to Godot's var_to_str
static func transform3d_to_str(val: Transform3D) -> String:
	return "%f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f" % [
		val.basis.x.x, val.basis.x.y, val.basis.x.z,
		val.basis.y.x, val.basis.y.y, val.basis.y.z,
		val.basis.z.x, val.basis.z.y, val.basis.z.z,
		val.origin.x, val.origin.y, val.origin.z
		]


# Convert from custom string format
static func str_to_vec3(string: String, str_version: int) -> Vector3:
	match str_version:
		0:
			var split = string.trim_prefix('(').trim_suffix(')').split_floats(', ')
			return Vector3(split[0], split[1], split[2])
		1:
			var split = string.split_floats(', ')
			return Vector3(split[0], split[1], split[2])
		_:
			push_error("Unsupported str version: %d" % [str_version])
			return Vector3.ZERO


# Convert from custom string format
static func str_to_transform3d(string: String, str_version: int) -> Transform3D:
	match str_version:
		0:
			string = string.replace(' - ', ', ')
			var split = string.split_floats(', ')
			return Transform3D(
				Vector3(split[0], split[3], split[6]), 
				Vector3(split[1], split[4], split[7]), 
				Vector3(split[2], split[5], split[8]), 
				Vector3(split[9], split[10], split[11]))
		1:
			var split = string.split_floats(', ')
			return Transform3D(
				Vector3(split[0], split[3], split[6]), 
				Vector3(split[1], split[4], split[7]), 
				Vector3(split[2], split[5], split[8]), 
				Vector3(split[9], split[10], split[11]))
		_:
			push_error("Unsupported str version: %d" % [str_version])
			return Transform3D()




#-------------------------------------------------------------------------------
# Math
#-------------------------------------------------------------------------------


# Clamp a value
# Automatically decide which value is min and which is max
static func clamp_auto(value, min_value, max_value):
	var direction = 1.0 if min_value <= max_value else -1.0
	if direction >= 0:
		if value < min_value:
			return min_value
		elif value > max_value:
			return max_value
	else:
		if value > min_value:
			return min_value
		elif value < max_value:
			return max_value
	
	return value


# Clamp all Vector3 properties individually
static func clamp_vector3(value:Vector3, min_value:Vector3, max_value:Vector3):
	var result = Vector3()
	result.x = clamp_auto(value.x, min_value.x, max_value.x)
	result.y = clamp_auto(value.y, min_value.y, max_value.y)
	result.z = clamp_auto(value.z, min_value.z, max_value.z)
	return result


# Lerp all Vector3 properties by 3 independent weights
static func vector_tri_lerp(from:Vector3, to:Vector3, weight:Vector3):
	return Vector3(
		lerp(from.x, to.x, weight.x),
		lerp(from.y, to.y, weight.y),
		lerp(from.z, to.z, weight.z)
	)




#-------------------------------------------------------------------------------
# Time
#-------------------------------------------------------------------------------


static func get_msec():
	return Time.get_ticks_msec()


static func msec_to_time(msec:int = -1, include_msec:bool = true, trim_mode:int = TimeTrimMode.NONE):
	if msec < 0:
		msec = get_msec()
	var time_units := [msec % 1000, msec / 1000 % 60, msec / 1000 / 60 % 60, msec / 1000 / 60 / 60 % 24]
	var string = ""
	
	if trim_mode != TimeTrimMode.NONE:
		for i in range(time_units.size() - 1, -1, -1):
			match trim_mode:
				TimeTrimMode.EXACT:
					if time_units[i] <= 0:
						time_units.remove_at(i)
					else:
						break
				TimeTrimMode.EXTRA_ONE:
					if  time_units[i] > 0:
						break
					if i + 1 < time_units.size() && time_units[i + 1] <= 0:
						time_units.remove_at(i + 1)
				TimeTrimMode.KEEP_ONE:
					if i >= 1:
						time_units.remove_at(i)
				TimeTrimMode.KEEP_TWO:
					if i >= 2:
						time_units.remove_at(i)
				TimeTrimMode.KEEP_THREE:
					if i >= 3:
						time_units.remove_at(i)
			
	
	
	for i in range(0, time_units.size()):
		var time_unit:int = time_units[i]
		
		if i == 0:
			if !include_msec: continue
			string = "%03d" % [time_units[i]]
		else:
			string = string.insert(0, "%02d:" % time_units[i])
	
	string = string.trim_suffix(":")
	
	return string


static func print_system_time(suffix:String = ""):
	print("[%s] : %s" % [Time.get_time_string_from_system(), suffix])




#-------------------------------------------------------------------------------
# Object class comparison
#-------------------------------------------------------------------------------


static func get_obj_class_string(obj:Object) -> String:
	if obj == null: return ""
	assert(is_instance_of(obj, Object))
	if obj.has_meta("class"):
		return obj.get_meta("class")
	elif obj.get_script():
		return obj.get_script().get_instance_base_type()
	else:
		return obj.get_class()


static func are_same_class(one:Object, two:Object) -> bool:
	if one == null: return false
	if two == null: return false
	assert(is_instance_of(one, Object) && is_instance_of(two, Object))
	
#	print("1 %s, 2 %s" % [one.get_class(), two.get_class()])
	
	if one.get_script() && two.get_script() && one.get_script() == two.get_script():
		return true
	elif one.has_meta("class") && two.has_meta("class") && one.get_meta("class") == two.get_meta("class"):
		return true
	elif one.get_class() == two.get_class():
		return true
#	elif !one.is_class(two.get_class()):
#		return true
	return false


static func obj_is_script(obj:Object, script:Script) -> bool:
	if obj == null: return false
	assert(is_instance_of(obj, Object))
	return obj.get_script() && obj.get_script() == script


static func obj_is_class_string(obj:Object, class_string:String) -> bool:
	if obj == null: return false
	assert(is_instance_of(obj, Object))
	
	if obj.get_class() == class_string:
		return true
	elif obj.has_meta("class") && obj.get_meta("class") == class_string:
		return true
	return false




#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------


# This is here to avoid circular reference lol
static func get_setting_safe(setting:String, default_value = null):
	if ProjectSettings.has_setting(setting):
		return ProjectSettings.get_setting(setting)
	return default_value




#-------------------------------------------------------------------------------
# Asset management
#-------------------------------------------------------------------------------


static func save_res(res:Resource, dir:String, res_name:String):
	assert(res)
	var logger = Logger.get_for_string("FunLib")
	var full_path = combine_dir_and_file(dir, res_name)
	if !is_dir_valid(dir): 
		logger.warn("Unable to save '%s', directory is invalid!" % [full_path])
		return 
	# Abort explicit saving if our resource and an existing one are the same instance
	# Since it will be saved on 'Ctrl+S' implicitly by the editor
	# And allows reverting resource by exiting the editor
	var loaded_res = load_res(dir, res_name, false, true)
	if res == loaded_res:
		return
	
	# There was a wall of text here regarding problems of saving and re-saving custom resources
	# But curiously, seems like it went away
	# These comments and previous state of saving/loading logic is available on commit '7b127ad'
	
	# Taking over path and subpaths is still required
	# Still keeping FLAG_CHANGE_PATH in case we want to save to a different location
	res.take_over_path(full_path)
	var err = ResourceSaver.save(res, full_path, ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	if err != OK:
		logger.error("Could not save '%s', error %s!" % [full_path, Globals.get_err_message(err)])


# Passing 'true' as 'no_cache' is important to bypass this cache
# We use it by default, but want to allow loading a cache to check if resource exists at path
static func load_res(dir:String, res_name:String, no_cache: bool = true, silent: bool = false) -> Resource:
	var full_path = combine_dir_and_file(dir, res_name)
	var res = null
	var logger = Logger.get_for_string("FunLib")
	
	if ResourceLoader.exists(full_path):
		res = ResourceLoader.load(full_path, "", ResourceLoader.CacheMode.CACHE_MODE_REPLACE if no_cache else ResourceLoader.CacheMode.CACHE_MODE_REUSE)
	else:
		if !silent: logger.warn("Path '%s', doesn't exist!" % [full_path])
	
	if !res:
		if !is_dir_valid(dir) || res_name == "":
			if !silent: logger.warn("Could not load '%s', error %s!" % [full_path, Globals.get_err_message(ERR_FILE_BAD_PATH)])
		else:
			if !silent: logger.warn("Could not load '%s'!" % [full_path])
	return res


static func remove_res(dir:String, res_name:String):
	var full_path = combine_dir_and_file(dir, res_name)
	var abs_path = ProjectSettings.globalize_path(full_path)
	var err = DirAccess.remove_absolute(abs_path)
	var logger = Logger.get_for_string("FunLib")
	if err != OK:
		logger.error("Could not remove '%s', error %s!" % [abs_path, Globals.get_err_message(err)])


static func combine_dir_and_file(dir_path: String, file_name: String):
	if !dir_path.is_empty() && !dir_path.ends_with("/"):
		dir_path += "/"
	return "%s%s" % [dir_path, file_name]


static func is_dir_valid(dir):
	return !dir.is_empty() && dir != "/" && DirAccess.dir_exists_absolute(dir)




#-------------------------------------------------------------------------------
# Filesystem
#-------------------------------------------------------------------------------


static func remove_dir_recursive(path, keep_first:bool = false) -> bool:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if !remove_dir_recursive(path + "/" + file_name, false):
					return false
			else:
				dir.remove(file_name)
			file_name = dir.get_next()
		
		if !keep_first:
			dir.remove(path)
		return true
	
	return false


static func iterate_files(dir_path: String, deep: bool, obj: Object, method_name: String, payload):
	if !is_instance_valid(obj): 
		assert('Object instace invalid!')
		return
	if !obj.has_method(method_name): 
		assert('%s does not have a method named "%s"!' % [str(obj), method_name])
		return
	
	var dir = DirAccess.open(dir_path)
	if dir_path.ends_with('/'):
		dir_path = dir_path.trim_suffix('/')
	if dir:
		dir.list_dir_begin()
		var full_path = ''
		var file_name = dir.get_next()
		while file_name != '':
			full_path = dir_path + "/" + file_name
			if deep && dir.current_is_dir():
				iterate_files(full_path, deep, obj, method_name, payload)
			else:
				obj.call(method_name, full_path, payload)
			file_name = dir.get_next()
