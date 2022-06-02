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


# 'free_existing' should be 'true' for resources, but 'false' for scenes
static func save_res(res:Resource, dir:String, res_name:String, free_existing:bool = true):
	if !dir.ends_with("/"): 
		dir += "/"
	assert(res)
	var logger = Logger.get_for_string("FunLib")
	var full_path = "%s%s" % [dir, res_name]
	
	# take_over_path() and ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
	# Are CRITICAL
		# (although ResourceSaver.FLAG_CHANGE_PATH seems unneccessary, but I'll keep it for good measure)
	# take_over_path() frees the path from a resource already cached from this path
		# This allows us to fully overtake that path
	# ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS takes over all the paths of subresources
		# This rejects/frees/whatever-the-hell-it-does the already cached subresources
		# Allowing us to reference only the up-to-date subresources, without any of the old ones
	# The alternative would be to free/dereference all kept references for the old resource, but that seems... unreasonable?
	
	# EDIT: This is not enough
	# See https://github.com/godotengine/godot/issues/24646
	# Editor holds cached version still and does not update it no matter what
	# I don't know how to solve this
	# And I can't even delete the resource and save it anew
	# Because it's still cached and will be overriden with that stupid cache
	
	# EDIT: There is some magic dance possible with closing, reopening and resaving
	# But it's nigh impossible to understand and replicate
	# And it's not guranteed to work in a standalone Gardener either
	
	# EDIT: Last two points above seem wrong
	# Saving of topmost resource goes without problems if we reset existing path with existing_res.resource_path = ""
	# But any subresources will retain their cached states
	# Curiously, recreating a simplified setup in a separate project (custom resource with nested arrays and subresources)
	# Seems to save everything correctly
	# Which most likely means my InputFieldResource is not very ResourceSaver friendly
	# In what way? I don't know. I was able to find a workaround, so I won't dwell on this problem for now
	# To solve the issue, we recursively iterate all exported properties of a resource
	# Upon finding a subresource, we reset it's resource_path as seen in res_free_path()
	# This seems to let us overwrite resource in project files and not face weird cahce-retaining behavior on it's subresources
	# TODO find the root cause of this issue. Probably delay this until conversion to Godot 4.0
	
	if ResourceLoader.exists(full_path) && free_existing:
		var existing_res = ResourceLoader.load(full_path, "", true)#)
		res_free_path(existing_res)
	
	res.take_over_path(full_path)
	var err = ResourceSaver.save(full_path, res, ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	if err != OK:
		logger.error("Could not save '%s', error %s!" % [full_path, Globals.get_err_message(err)])


static func res_free_path(res):
	if res is Array:
		for arr_val in res:
			res_free_path(arr_val)
	elif res is Dictionary:
		for arr_val in res.values():
			res_free_path(arr_val)
	elif res is Resource:
		for prop in res.get_property_list():
			res_free_path(res.get(prop.name))
		if res.has_method("duplicate_ifr"):
			res.resource_path = ""
#			print("freed %s" % [res.resource_name])


static func load_res(dir:String, res_name:String, default_res:Resource = null) -> Resource:
	if !dir.ends_with("/"): 
		dir += "/"
	var full_path = "%s%s" % [dir, res_name]
	var res = null
	var logger = Logger.get_for_string("FunLib")
	
	if ResourceLoader.exists(full_path):
		res = ResourceLoader.load(full_path, "", true)
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
	
	return res#.duplicate()


static func is_dir_valid(dir):
	return dir != "" && dir != "/" && Directory.new().dir_exists(dir)
