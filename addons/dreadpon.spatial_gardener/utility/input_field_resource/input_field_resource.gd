@tool
extends Resource


#-------------------------------------------------------------------------------
# A base class for resources bound with InputFields and suporting UndoRedo
# All properties are suppposed to be set using PropAction
# That helps to easily update UI and do/undo actions in editor
# There's also a bit of property management sprinkled on top (conditional display, modified values, etc.)
#
# TODO: reduce amount of abstractions and indirections. 
#		overhead for function calls and container usage is the most demanding part of this thing
#-------------------------------------------------------------------------------


enum PropActionLifecycle {BEFORE_DO, AFTER_DO, AFTER_UNDO}


const Logger = preload("../logger.gd")
const FunLib = preload("../fun_lib.gd")

const PropAction = preload("prop_action.gd")
const PA_PropSet = preload("pa_prop_set.gd")
const PA_PropEdit = preload("pa_prop_edit.gd")
const PA_ArrayInsert = preload("pa_array_insert.gd")
const PA_ArrayRemove = preload("pa_array_remove.gd")
const PA_ArraySet = preload("pa_array_set.gd")

const UI_ActionThumbnail_GD = preload("../../controls/input_fields/action_thumbnail/ui_action_thumbnail.gd")
const UI_InputField = preload("../../controls/input_fields/ui_input_field.gd")
const UI_IF_Bool = preload("../../controls/input_fields/ui_if_bool.gd")
const UI_IF_Enum = preload("../../controls/input_fields/ui_if_enum.gd")
const UI_IF_MultiRange = preload("../../controls/input_fields/ui_if_multi_range.gd")
const UI_IF_RealSlider = preload("../../controls/input_fields/ui_if_real_slider.gd")
const UI_IF_IntSlider = preload("../../controls/input_fields/ui_if_int_slider.gd")
const UI_IF_IntLineEdit = preload("../../controls/input_fields/ui_if_int_line_edit.gd")
const UI_IF_ThumbnailArray = preload("../../controls/input_fields/ui_if_thumbnail_array.gd")
const UI_IF_ApplyChanges = preload("../../controls/input_fields/ui_if_apply_changes.gd")
const UI_IF_Button = preload("../../controls/input_fields/ui_if_button.gd")
const UI_IF_PlainText = preload("../../controls/input_fields/ui_if_plain_text.gd")
const UI_IF_Object = preload("../../controls/input_fields/ui_if_object.gd")
const UI_IF_ThumbnailObject = preload("../../controls/input_fields/ui_if_thumbnail_object.gd")
const UI_IF_IntFlags = preload("../../controls/input_fields/ui_if_int_flags.gd")
const UndoRedoInterface = preload("../../utility/undo_redo_interface.gd")


var _undo_redo = null : set = set_undo_redo
# Backups that can be restored when using non-destructive PA_PropEdit
var prop_edit_backups:Dictionary = {}
# Properties added here will be ignored when creating input fields
# NOTE: this is meant to exclude properties from generating an input field AT ALL
#		it's NOT a conditional check to show/hide fields
#		it will be used once when generating a UI layout, but not to modify it
# NOTE: for conditional checks see 'visibility_tracked_properties' in ui_input_filed.gd
#		to hide properties from editor's inspector see _get_prop_dictionary()
var input_field_blacklist:Array = []
# All properties that are linked together for showing an element of an Array
var res_edit_data:Array = []
# All properties that are affected by other properties
var prop_dependency_data:Array = []

var logger = null


signal prop_action_executed(prop_action, final_val)
signal req_change_interaction_feature(prop, index, feature, val)
signal prop_list_changed(prop_names)




#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


func _init():
	set_meta("class", "InputFieldResource")
	resource_name = "InputFieldResource"
	logger = Logger.get_for(self)
	FunLib.ensure_signal(self.prop_action_executed, _on_prop_action_executed)


func set_undo_redo(val):
	_undo_redo = val


# This doesn't account for resources inside nested Arrays/Dictionaries (i.e. [[Resource:1, Resource:2], [Resource:3]])
func duplicate_ifr(subresources:bool = false, ifr_subresources:bool = false) -> Resource:
	var copy = super.duplicate(false)
	
	if subresources || ifr_subresources:
		var property_list = copy.get_property_list()
		for prop_dict in property_list:
			var prop = prop_dict.name
			var prop_val = copy.get(prop)
			
			if prop_val is Array || prop_val is Dictionary:
				prop_val = prop_val.duplicate(true)
				copy._set(prop, prop_val)
				
				if prop_val is Array:
					for i in range(0, prop_val.size()):
						var element = prop_val[i]
						if is_instance_of(element, Resource):
							if element.has_method("duplicate_ifr") && ifr_subresources:
								prop_val[i] = element.duplicate_ifr(subresources, ifr_subresources)
							elif subresources:
								prop_val[i] = element.duplicate(subresources)
				
				elif prop_val is Dictionary:
					for key in prop_val.keys():
						var element = prop_val[key]
						if is_instance_of(element, Resource):
							if element.has_method("duplicate_ifr") && ifr_subresources:
								prop_val[key] = element.duplicate_ifr(subresources, ifr_subresources)
							elif subresources:
								prop_val[key] = element.duplicate(subresources)
			
			# Script check makes sure we don't try to duplicate Script properties
			# This... shouldn't be happening normally
			# TODO the whole InputFieldResource is kind of a mess, would be great if we could fit that into existing inspector workflow
			elif is_instance_of(prop_val, Resource) && !is_instance_of(prop_val, Script):
				if prop_val.has_method("duplicate_ifr") && ifr_subresources:
					prop_val = prop_val.duplicate_ifr(subresources, ifr_subresources)
				elif subresources:
					prop_val = prop_val.duplicate(subresources)
				copy._set(prop, prop_val)
	
	return copy


func duplicate(subresources:bool = false):
	var copy = duplicate_ifr(subresources, true)
	_fix_duplicate_signals(copy)
	return copy


# Convert Input Field Resource to a dictionary
func ifr_to_dict(ifr_subresources:bool = false):
	var dict = {}
	
	for prop_dict in _get_property_list():
		if find_res_edit_by_res_prop(prop_dict.name):
			continue
		
		var prop_val = _get(prop_dict.name)
		
		if prop_val is Array || prop_val is Dictionary:
			prop_val = prop_val.duplicate(true)
			
			if prop_val is Array:
				for i in range(0, prop_val.size()):
					var element = prop_val[i]
					prop_val[i] = _ifr_val_to_dict_compatible(element, ifr_subresources)
			
			elif prop_val is Dictionary:
				for key in prop_val.keys():
					var element = prop_val[key]
					prop_val[key] = _ifr_val_to_dict_compatible(element, ifr_subresources)
		
		else:
			prop_val = _ifr_val_to_dict_compatible(prop_val, ifr_subresources)
		
		dict[prop_dict.name] = prop_val
	
	return dict


# Convert Input Field Resource value from native to dictionary-compatible (and independent of native var_to_str)
func _ifr_val_to_dict_compatible(val, ifr_subresources):
	if ifr_subresources && is_instance_of(val, Resource) && !is_instance_of(val, Script):
		if val.has_method("ifr_to_dict") && ifr_subresources:
			val = val.ifr_to_dict(ifr_subresources)
		else:
			val = val.resource_path
	
	elif typeof(val) == TYPE_VECTOR3:
		val = FunLib.vec3_to_str(val)
		
	elif typeof(val) == TYPE_TRANSFORM3D:
		val = FunLib.transform3d_to_str(val)
	
	return val


# Convert dictionary to an Input Field Resource
func ifr_from_dict(dict: Dictionary, ifr_subresources:bool = false, str_version: int = 1) -> Resource:
	for prop_dict in _get_property_list():
		if find_res_edit_by_res_prop(prop_dict.name):
			continue
		
		var prop_val = dict.get(prop_dict.name, null)
		var existing_prop_val = _get(prop_dict.name)
		
		if prop_val is Array:
			existing_prop_val.resize(prop_val.size())
			# Trigger automatic creation of default Resource
			_set(prop_dict.name, existing_prop_val)
			for i in range(0, prop_val.size()):
				var element = existing_prop_val[i]
				prop_val[i] = _dict_compatible_to_ifr_val(element, prop_val[i], ifr_subresources, str_version)
		
		elif prop_val is Dictionary:
			prop_val = _dict_compatible_to_ifr_val(existing_prop_val, prop_val, ifr_subresources, str_version)
			if prop_val is Dictionary:
				for key in prop_val.keys():
					existing_prop_val[key] = prop_val.get(key, null)
				# Trigger automatic creation of default Resource
				_set(prop_dict.name, existing_prop_val)
				for key in prop_val.keys():
					var element = existing_prop_val[key]
					prop_val[key] = _dict_compatible_to_ifr_val(element, prop_val[key], ifr_subresources, str_version)
		
		else:
			prop_val = _dict_compatible_to_ifr_val(existing_prop_val, prop_val, ifr_subresources, str_version)
		
		_set(prop_dict.name, prop_val)
	
	return self


# Convert dictionary-compatible (and independent of native var_to_str) value to an Input Field Resource value
func _dict_compatible_to_ifr_val(template_val, val, ifr_subresources, str_version):
	if ifr_subresources && is_instance_of(template_val, Resource) && !is_instance_of(template_val, Script):
		if template_val.has_method("ifr_from_dict") && ifr_subresources:
			val = template_val.ifr_from_dict(val, ifr_subresources, str_version)
	
	elif val is String && ResourceLoader.exists(val):
		val = ResourceLoader.load(val)
	
	elif typeof(template_val) == TYPE_VECTOR3:
		val = FunLib.str_to_vec3(val, str_version)
	
	elif typeof(template_val) == TYPE_TRANSFORM3D:
		val = FunLib.str_to_transform3d(val, str_version)
	
	return val


# It turns out, duplicating subresources implies we need to reconnect them to any *other* duplicated resources
# e.g. brushes to the toolshed (Obvious in retrospective, I know)
# Ideally they would reconnect automatically, and possibly that's what Godot's native duplicate() does (but I haven't checked)
# For now we will fix this by hand for any resource that inherits from InputFieldResource
# TODO explore if Godot handles subresource signal reconnection. If yes - try to utilize the native code. If not - write my own
func _fix_duplicate_signals(copy):
	pass



#-------------------------------------------------------------------------------
# Handling property actions
#-------------------------------------------------------------------------------


# A wrapper with a better name
func request_prop_action(prop_action:PropAction):
	on_prop_action_requested(prop_action)


# A callback for any requests to change the properties
func on_prop_action_requested(prop_action:PropAction):
	debug_print_prop_action("Requested prop action: %s..." % [str(prop_action)])
	
	if _undo_redo && _can_prop_action_create_history(prop_action):
		var prop_action_class = prop_action.get_meta("class")
		UndoRedoInterface.create_action(_undo_redo, "%s: on '%s'" % [prop_action_class, prop_action.prop], 0, false, self)
		_prop_action_request_lifecycle(prop_action, PropActionLifecycle.BEFORE_DO)
		UndoRedoInterface.add_do_method(_undo_redo, self._perform_prop_action.bind(prop_action))
		_prop_action_request_lifecycle(prop_action, PropActionLifecycle.AFTER_DO)
		UndoRedoInterface.add_undo_method(_undo_redo, self._perform_prop_action.bind(_get_opposite_prop_action(prop_action)))
		_prop_action_request_lifecycle(prop_action, PropActionLifecycle.AFTER_UNDO)
		UndoRedoInterface.commit_action(_undo_redo, true)
	# But we don't *have* to use UndoRedo system
	else:
		_prop_action_request_lifecycle(prop_action, PropActionLifecycle.BEFORE_DO)
		_perform_prop_action(prop_action)
		_prop_action_request_lifecycle(prop_action, PropActionLifecycle.AFTER_DO)


# A wrapper for prop_action_request_lifecycle() with default logic
func _prop_action_request_lifecycle(prop_action:PropAction, lifecycle_stage:int):
	_handle_res_edit_prop_action_lifecycle(prop_action, lifecycle_stage)
	_handle_dependency_prop_action_lifecycle(prop_action, lifecycle_stage)
	prop_action_request_lifecycle(prop_action, lifecycle_stage)


# Custom logic after a PropAction was requested/done/undone
# To be overridden
func prop_action_request_lifecycle(prop_action:PropAction, lifecycle_stage:int):
	pass


# Can a given prop action create UndoRedo history?
	# Most of the time we need this is when using a UI slider
	# To avoid commiting dozens of history actions while dragging
func _can_prop_action_create_history(prop_action:PropAction):
	var enable_undo_redo = FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/greenhouse_ui_enable_undo_redo", true)
	return prop_action.can_create_history && enable_undo_redo


# Performs the prop action
func _perform_prop_action(prop_action:PropAction):
	var prop_action_class = prop_action.get_meta("class")
	var current_val_copy = _get_current_val_copy(prop_action.prop)
	
	debug_print_prop_action("Performing prop action: %s..." % [str(prop_action)])
	
	# 'prop_action.val = get(prop_action.prop)' and it's variations
	# Account for _modify_prop() modifying the property
	# E.g. an array replacing null elements with actual instances
	# This does not apply to PA_ArrayRemove since we assume a removed element will not be changed
	match prop_action_class:
		"PA_PropSet":
			_erase_prop_edit_backup(prop_action.prop)
			_set(prop_action.prop, prop_action.val)
			prop_action.val = get(prop_action.prop)
		"PA_PropEdit":
			_make_prop_edit_backup(prop_action.prop)
			_set(prop_action.prop, prop_action.val)
			prop_action.val = get(prop_action.prop)
		"PA_ArrayInsert":
			current_val_copy.insert(prop_action.index, prop_action.val)
			_set(prop_action.prop, current_val_copy)
			prop_action.val = get(prop_action.prop)[prop_action.index]
		"PA_ArrayRemove":
			prop_action.val = current_val_copy[prop_action.index]
			current_val_copy.remove_at(prop_action.index)
			_set(prop_action.prop, current_val_copy)
		"PA_ArraySet":
			current_val_copy[prop_action.index] = prop_action.val
			_set(prop_action.prop, current_val_copy)
			prop_action.val = get(prop_action.prop)[prop_action.index]
		_:
			logger.error("Error: PropAction class \"%s\" is not accounted for" % [prop_action_class])
			return
	
	res_edit_update_interaction_features(prop_action.prop)
	
	prop_action_executed.emit(prop_action, get(prop_action.prop))


# Reverses the prop action (used for undo actions)
func _get_opposite_prop_action(prop_action:PropAction) -> PropAction:
	var prop_action_class = prop_action.get_meta("class")
	var current_val_copy = _get_current_val_copy(prop_action.prop)
	
	match prop_action_class:
		"PA_PropSet":
			return PA_PropSet.new(prop_action.prop, current_val_copy)
		"PA_PropEdit":
			return PA_PropEdit.new(prop_action.prop, current_val_copy)
		"PA_ArrayInsert":
			return PA_ArrayRemove.new(prop_action.prop, null, prop_action.index)
		"PA_ArrayRemove":
			return PA_ArrayInsert.new(prop_action.prop, current_val_copy[prop_action.index], prop_action.index)
		"PA_ArraySet":
			return PA_ArraySet.new(prop_action.prop, current_val_copy[prop_action.index], prop_action.index)
		_:
			logger.error("Error: PropAction class \"%s\" is not accounted for" % [prop_action_class])
	return null


# Backup a current property before a PA_PropEdit
# Since PA_PropEdit is non-destructive to UndoRedo history, we need a separate PA_PropSet to make do/undo actions
# This backup is used to cache the initial property value and retrieve it when setting an undo action
func _make_prop_edit_backup(prop:String):
	if prop_edit_backups.has(prop): return
	prop_edit_backups[prop] = _get_current_val_copy(prop)


# Cleanup the backup
func _erase_prop_edit_backup(prop:String):
	prop_edit_backups.erase(prop)


# Get the copy of CURRENT state of the value
# Does not copy objects because of possible abiguity of intention
func _get_current_val_copy(prop:String):
	var copy
	if prop_edit_backups.has(prop):
		copy = prop_edit_backups[prop]
	else:
		copy = get(prop)
	
	if copy is Array || copy is Dictionary:
		copy = copy.duplicate()
	return copy


# A wrapper for on_prop_action_executed() with default logic
func _on_prop_action_executed(prop_action:PropAction, final_val):
	on_prop_action_executed(prop_action, final_val)


# A built-in callback for when a PropAction was executed
# To be overridden
func on_prop_action_executed(prop_action:PropAction, final_val):
	pass




#-------------------------------------------------------------------------------
# Property export
#-------------------------------------------------------------------------------


# Modify a property
# Mostly used to initialize a newly added array/dictionary value when setting array size from Engine Inspector
# To be overridden and (usually) called inside a _set()
func _modify_prop(prop:String, val):
	return val


# Map property info to a dictionary for convinience
# To be overridden and (usually) called inside a _get_property_list()
func _get_prop_dictionary() -> Dictionary:
	return {}


# Get property data from a dictionary and filter it
# Allows easier management of hidden/shown properties based on arbitrary conditions in a subclass
# To be overridden and (usually) called inside a _get_property_list() 
# 	With a dictionary created by _get_prop_dictionary()
# Return the same prop_dict passed to it (for convenience in function calls)
func _filter_prop_dictionary(prop_dict: Dictionary) -> Dictionary:
	return prop_dict


func _set(property, val):
	pass


func _get(property):
	pass


# Default functionality for _get_property_list():
# Get all {prop_name: prop_data_dictionary} defined by _get_prop_dictionary()
# Filter them (optionally rejecting some of them based on arbitrary conditions)
# Return a prop_dict values array
func _get_property_list():
	var prop_dict = _get_prop_dictionary()
	_filter_prop_dictionary(prop_dict)
	return prop_dict.values()


# A wrapper around built-in notify_property_list_changed()
# To support a custom signal we can bind manually
func _emit_property_list_changed_notify():
	notify_property_list_changed()
	prop_list_changed.emit(_filter_prop_dictionary(_get_prop_dictionary()))




#-------------------------------------------------------------------------------
# UI Management
#-------------------------------------------------------------------------------


# Create all the UI input fields
# input_field_blacklist is responsible for excluding certain props
# Optionally specify a whitelist to use instead of an object-wide blacklist
# They both allow to conditionally hide/show input fields
func create_input_fields(_base_control:Control, _resource_previewer, whitelist:Array = []) -> Dictionary:
#	print("create_input_fields %s %s %d start" % [str(self), get_meta("class"), Time.get_ticks_msec()])
	var prop_names = _get_prop_dictionary().keys()
	var input_fields := {}
	
	for prop in prop_names:
		# Conditional rejection of a property
		if whitelist.is_empty():
			if input_field_blacklist.has(prop): continue
		else:
			if !whitelist.has(prop): continue
		
		var input_field:UI_InputField = create_input_field(_base_control, _resource_previewer, prop)
		if input_field:
			input_fields[prop] = input_field
	return input_fields


func create_input_field(_base_control:Control, _resource_previewer, prop:String) -> UI_InputField:
	
	var input_field = _create_input_field(_base_control, _resource_previewer, prop)
	if input_field:
		input_field.name = prop
		input_field.set_tooltip(get_prop_tooltip(prop))
		input_field.on_prop_list_changed(_filter_prop_dictionary(_get_prop_dictionary()))
		
		input_field.prop_action_requested.connect(request_prop_action)
		prop_action_executed.connect(input_field.on_prop_action_executed)
		prop_list_changed.connect(input_field.on_prop_list_changed)
		input_field.tree_entered.connect(on_if_tree_entered.bind(input_field))
		
		if is_instance_of(input_field, UI_IF_ThumbnailArray):
			input_field.requested_press.connect(on_if_thumbnail_array_press.bind(input_field))
			req_change_interaction_feature.connect(input_field.on_changed_interaction_feature)
		# NOTE: below is a leftover abstraction from an attempt to create ui nodes only once and reuse them
		#		but it introduced to many unknowns to be viable as a part of Godot 3.5 -> Godot 4.0 transition
		#		yet it stays, as a layer of abstraction
		# TODO: implement proper reuse of ui nodes
		#		or otherwise speed up their creation
		input_field.prepare_input_field(_get(prop), _base_control, _resource_previewer)
	
	
	return input_field


# Creates a specified input field
# To be overridden
func _create_input_field(_base_control:Control, _resource_previewer, prop:String) -> UI_InputField:
	return null


# Do something with an input field when it's _ready()
func on_if_tree_entered(input_field:UI_InputField):
	var res_edit = find_res_edit_by_array_prop(input_field.prop_name)
	if res_edit:
		var res_val = get(res_edit.res_prop)
		# We assume that input field that displays the resource is initialized during infput field creation
		# And hense only update the array interaction features
		res_edit_update_interaction_features(res_edit.res_prop)


# An array thumbnail representing a resource was pressed
func on_if_thumbnail_array_press(pressed_index:int, input_field:Control):
	var res_edit = find_res_edit_by_array_prop(input_field.prop_name)
	if res_edit:
		var array_val = get(res_edit.array_prop)
		var new_res_val = array_val[pressed_index]
		_res_edit_select(res_edit.array_prop, [new_res_val], true)


# Get a tooltip string for each property to be used in it's InputField
func get_prop_tooltip(prop:String) -> String:
	return ""




#-------------------------------------------------------------------------------
# Prop dependency
#-------------------------------------------------------------------------------


# Register a property dependency (where any of the controlling_props might change the dependent_prop)
# This is needed for correct UndoRedo functionality
func _add_prop_dependency(dependent_prop:String, controlling_props:Array):
	prop_dependency_data.append({"dependent_prop": dependent_prop, "controlling_props": controlling_props})


# React to lifecycle stages for properties that are affected by other properties
func _handle_dependency_prop_action_lifecycle(prop_action:PropAction, lifecycle_stage:int):
	var prop_action_class = prop_action.get_meta("class")
	
	var dependency = find_dependency_by_controlling_prop(prop_action.prop)
	if dependency && prop_action_class == "PA_PropSet":
		var new_prop_action = PA_PropSet.new(dependency.dependent_prop, get(dependency.dependent_prop))
		
		if _undo_redo && _can_prop_action_create_history(new_prop_action):
			if lifecycle_stage == PropActionLifecycle.AFTER_DO:
				UndoRedoInterface.add_do_method(_undo_redo, self._perform_prop_action.bind(new_prop_action))
			elif lifecycle_stage == PropActionLifecycle.AFTER_UNDO:
				UndoRedoInterface.add_undo_method(_undo_redo, self._perform_prop_action.bind(_get_opposite_prop_action(new_prop_action)))
		else:
			if lifecycle_stage == PropActionLifecycle.AFTER_DO:
				_perform_prop_action(new_prop_action)




#-------------------------------------------------------------------------------
# Res edit
#-------------------------------------------------------------------------------


# Register a property array with resources that can be individually shown for property editing
# Since new ones are added as 'null' and initialized in _modify_prop(), so they WILL NOT be equal to cached ones in UndoRedo actions
func _add_res_edit_source_array(array_prop:String, res_prop:String):
	res_edit_data.append({"array_prop": array_prop, "res_prop": res_prop})


# React to lifecycle stages for actions executed on res_edit_data members
func _handle_res_edit_prop_action_lifecycle(prop_action:PropAction, lifecycle_stage:int):
	var prop_action_class = prop_action.get_meta("class")
	var res_edit = find_res_edit_by_array_prop(prop_action.prop)
	
	if res_edit:
		var array_prop = res_edit.array_prop
		var array_val = get(array_prop)
		var res_val = get(res_edit.res_prop)
		var current_index = array_val.find(res_val)
		
		match prop_action_class:
			"PA_ArrayRemove":
				if current_index == prop_action.index:
					if _undo_redo && _can_prop_action_create_history(prop_action):
						if lifecycle_stage == PropActionLifecycle.AFTER_DO:
							_undo_redo.add_do_method(self, "_res_edit_select", array_prop, [null])
						elif lifecycle_stage == PropActionLifecycle.AFTER_UNDO:
							_undo_redo.add_undo_method(self, "_res_edit_select", array_prop, [res_val])
					else:
						if lifecycle_stage == PropActionLifecycle.AFTER_DO:
							_res_edit_select(array_prop, [null])
			"PA_ArraySet":
				var new_res_val = prop_action.val
				
				if current_index == prop_action.index:
					if _undo_redo && _can_prop_action_create_history(prop_action):
						if lifecycle_stage == PropActionLifecycle.AFTER_DO:
							_undo_redo.add_do_method(self, "_res_edit_select", array_prop, [new_res_val])
						elif lifecycle_stage == PropActionLifecycle.AFTER_UNDO:
							_undo_redo.add_undo_method(self, "_res_edit_select", array_prop, [res_val])
					else:
						if lifecycle_stage == PropActionLifecycle.AFTER_DO:
							_res_edit_select(array_prop, [new_res_val])


# Requests a prop action that updates the needed property
func _res_edit_select(array_prop:String, new_res_array:Array, create_history:bool = false):
	
	var res_edit = find_res_edit_by_array_prop(array_prop)
	if res_edit:
		var array_val = get(res_edit.array_prop)
		var res_val = get(res_edit.res_prop)
		var new_res_val = new_res_array[0]
		if res_val == new_res_val:
			new_res_val = null
		
		var prop_action = PA_PropSet.new(res_edit.res_prop, new_res_val)
		prop_action.can_create_history = create_history
		request_prop_action(prop_action)




#-------------------------------------------------------------------------------
# Prop dependency misc
#-------------------------------------------------------------------------------


func find_dependency_by_dependent_prop(dependent_prop:String):
	for dependency in prop_dependency_data:
		if dependency.dependent_prop == dependent_prop:
			return dependency
	return null


func find_dependency_by_controlling_prop(controlling_prop:String):
	for dependency in prop_dependency_data:
		if dependency.controlling_props.has(controlling_prop):
			return dependency
	return null






#-------------------------------------------------------------------------------
# Res edit misc
#-------------------------------------------------------------------------------


func find_res_edit_by_array_prop(array_prop:String):
	for res_edit in res_edit_data:
		if res_edit.array_prop == array_prop:
			return res_edit
	return null


func find_res_edit_by_res_prop(res_prop:String):
	for res_edit in res_edit_data:
		if res_edit.res_prop == res_prop:
			return res_edit
	return null


func res_edit_update_interaction_features(res_prop:String):
	var res_edit = find_res_edit_by_res_prop(res_prop)
	if res_edit == null || res_edit.is_empty(): return
	
	var array_val = get(res_edit.array_prop)
	
	for i in range(0, array_val.size()):
		var res_val = get(res_edit.res_prop)
		var res_val_at_index = array_val[i]
		
		if res_val_at_index == res_val:
			req_change_interaction_feature.emit(res_edit.array_prop, UI_ActionThumbnail_GD.InteractionFlags.PRESS, true, {"index": i})
		else:
			req_change_interaction_feature.emit(res_edit.array_prop, UI_ActionThumbnail_GD.InteractionFlags.PRESS, false, {"index": i})




#-------------------------------------------------------------------------------
# Debug
#-------------------------------------------------------------------------------


# Debug print with a ProjectSettings check
func debug_print_prop_action(string:String):
	if !FunLib.get_setting_safe("dreadpons_spatial_gardener/debug/input_field_resource_log_prop_actions", false): return
	logger.info(string)
