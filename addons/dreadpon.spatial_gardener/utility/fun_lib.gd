tool


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
static func clear_children(node):
	if !is_instance_valid(node): return
	for child in node.get_children().duplicate():
		node.remove_child(child)
		child.queue_free()


# A shorthand for checking/connecting a signal
# Kinda wish Godot had a built-in one
static func ensure_signal(source:Object, _signal:String, target:Object, method:String, binds:Array = [], flags:int = 0):
	if !source.is_connected(_signal, target, method):
		source.connect(_signal, target, method, binds, flags)




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
	return OS.get_ticks_msec()


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
						time_units.remove(i)
					else:
						break
				TimeTrimMode.EXTRA_ONE:
					if  time_units[i] > 0:
						break
					if i + 1 < time_units.size() && time_units[i + 1] <= 0:
						time_units.remove(i + 1)
				TimeTrimMode.KEEP_ONE:
					if i >= 1:
						time_units.remove(i)
				TimeTrimMode.KEEP_TWO:
					if i >= 2:
						time_units.remove(i)
				TimeTrimMode.KEEP_THREE:
					if i >= 3:
						time_units.remove(i)
			
	
	
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
	var time = OS.get_time()
	var msecond = OS.get_ticks_msec() % 1000
	var time_formatted = String(time.hour) +":"+String(time.minute)+":"+String(time.second)+":"+String(msecond)
	print(time_formatted + " " + suffix)




#-------------------------------------------------------------------------------
# Object class comparison
#-------------------------------------------------------------------------------


static func get_obj_class_string(obj:Object) -> String:
	if obj == null: return ""
	assert(obj is Object)
	if obj.has_meta("class"):
		return obj.get_meta("class")
	elif obj.get_script():
		return obj.get_script().get_instance_base_type()
	else:
		return obj.get_class()


static func are_same_class(one:Object, two:Object) -> bool:
	if one == null: return false
	if two == null: return false
	assert(one is Object && two is Object)
	
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
	assert(obj is Object)
	return obj.get_script() && obj.get_script() == script


static func obj_is_class_string(obj:Object, class_string:String) -> bool:
	if obj == null: return false
	assert(obj is Object)
	
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
	
	# Abort explicit saving if our resource and an existing one are the same instance
	# Since it will be saved on 'Ctrl+S' implicitly by the editor
	# And allows reverting resource by exiting the editor
	var loaded_res = load_res(dir, res_name, null, false)
	if res == loaded_res:
		return
	
	# There was a wall of text here regarding problems of saving and re-saving custom resources
	# But curiously, seems like it went away
	# These comments and previous state of saving/loading logic is available on commit '7b127ad'
	
	# Taking over path and subpaths is still required
	# Still keeping FLAG_CHANGE_PATH in case we want to save to a different location
	res.take_over_path(full_path)
	var err = ResourceSaver.save(full_path, res, ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	if err != OK:
		logger.error("Could not save '%s', error %s!" % [full_path, Globals.get_err_message(err)])


# Passing 'true' as 'no_cache' is important to bypass this cache
# We use it by default, but want to allow loading a cache to check if resource exists at path
static func load_res(dir:String, res_name:String, default_res:Resource = null, no_cache: bool = true) -> Resource:
	var full_path = combine_dir_and_file(dir, res_name)
	var res = null
	var logger = Logger.get_for_string("FunLib")
	
	if ResourceLoader.exists(full_path):
		res = ResourceLoader.load(full_path, "", no_cache)
	elif is_instance_valid(default_res):
		res = default_res.duplicate(true)
		logger.info("Path '%s', doesn't exist. Using default resource." % [full_path])
	else:
		logger.warn("Path '%s', doesn't exist. No default resource exists either!" % [full_path])
	
	if !res:
		if !is_dir_valid(dir) || res_name == "":
			logger.warn("Could not load '%s', error %s!" % [full_path, Globals.get_err_message(ERR_FILE_BAD_PATH)])
		else:
			logger.warn("Could not load '%s'!" % [full_path])
	
	return res


static func combine_dir_and_file(dir_path: String, file_name: String):
	if !dir_path.ends_with("/"):
		dir_path += "/"
	return "%s%s" % [dir_path, file_name]


static func is_dir_valid(dir):
	return dir != "" && dir != "/" && Directory.new().dir_exists(dir)
