tool
extends "../utility/input_field_resource/input_field_resource.gd"


#-------------------------------------------------------------------------------
# All the data needed to generate a plant, it's transform
# And a containing octree
#-------------------------------------------------------------------------------


var Globals = preload("../utility/globals.gd")
const Greenhouse_LODVariant = preload("greenhouse_LOD_variant.gd")


enum ScalingType {UNIFORM, FREE, LOCK_XY, LOCK_ZY, LOCK_XZ}
enum DirectionVectorType {UNUSED, WORLD_X, WORLD_Y, WORLD_Z, NORMAL, CUSTOM}




# Different LODs for a plant starting from the most detailed
var mesh_LOD_variants:Array = []
# Keep a reference to selected resource to easily display it
var selected_for_edit_resource:Resource = null
# Distance after which the final LOD is shown
var mesh_LOD_max_distance:float = 10.0
# Distance after which the mesh is hidden
var mesh_LOD_kill_distance:float = -1.0

# How many members fit into an octree node before it's subdivided
var mesh_LOD_max_capacity:int = 75
# Minimum size of an octree node. Will not subdivide after this treshold
# Chunks of minimum size might contain members beyond the capacity limit
var mesh_LOD_min_size:float = 1.0
# A dummy variable to show a dialog for recreating an octree
var octree_reconfigure_button:bool = false
# A dummy variable to recenter an octree
var octree_recenter_button:bool = false

# How many members spawn in a 2D square of PLANT_DENSITY_UNITS aligned to a brush
# These members will then be projected onto a surface
var density_per_units:float = 100.0

# How we constraint the scale (uniform scale, unrestricted or to specific 3D plane)
var scale_scaling_type:int = ScalingType.UNIFORM
# A range of scale to randomize into
var scale_range:Array = [Vector3(1,1,1), Vector3(1,1,1)]

# How we choose the primary up vector
var up_vector_primary_type:int = DirectionVectorType.WORLD_Y
# Custom value for primary up vector if enabled
var up_vector_primary:Vector3 = Vector3()
# How we choose the secondary up vector
var up_vector_secondary_type:int = DirectionVectorType.WORLD_Y
# Custom value for secondary up vector if enabled
var up_vector_secondary:Vector3 = Vector3()
# Weight for blending between two up vectors
var up_vector_blending:float = 0.0

# How we choose the primary forward vector
var fwd_vector_primary_type:int = DirectionVectorType.UNUSED
# Custom value for primary forward vector if enabled
var fwd_vector_primary:Vector3 = Vector3()
# How we choose the secondary forward vector
var fwd_vector_secondary_type:int = DirectionVectorType.UNUSED
# Custom value for secondary forward vector if enabled
var fwd_vector_secondary:Vector3 = Vector3()
# Weight for blending between two forward vectors
var fwd_vector_blending:float = 0.0

# A range of vertical scale to randomize into (local to plant y axis)
var offset_y_range:Array = [0.0, 0.0]
# A random horizontal jitter applied when placing each instance
# A fraction of a cell, that plant is placed in (i.e. is in range (0.0, 1.0)
var offset_jitter_fraction:float = 0.6

# Random rotation in y axis (will be between (-val, val))
var rotation_random_y:float = 180.0
# Random rotation in x axis (will be between (-val, val))
var rotation_random_x:float = 0.0
# Random rotation in z axis (will be between (-val, val))
var rotation_random_z:float = 0.0

# Limits placement onto a sloped surface
# "Sloped" in relation to the chosen primary up vector
var slope_allowed_range:Array = [0.0, 180.0]

# A dummy variable to export plant instance transforms
var import_export_import_button:bool = false
# A dummy variable to import plant instance transforms
var import_export_export_button:bool = false


var total_instances_in_gardener:int = 0
var _base_control = null
var _resource_previewer = null
var select_container = null
var settings_container = null


signal req_octree_reconfigure
signal req_octree_recenter
signal req_import_transforms
signal req_export_transforms
signal prop_action_executed_on_LOD_variant(prop_action, final_val, LOD_variant)




#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


func _init().():
	set_meta("class", "Greenhouse_Plant")
	resource_name = "Greenhouse_Plant"
	
	input_field_blacklist = ["mesh/mesh_LOD_max_capacity", "mesh/mesh_LOD_min_size"]
	_add_prop_dependency("mesh/mesh_LOD_kill_distance", ["mesh/mesh_LOD_max_distance"])
	_add_prop_dependency("scale/scale_range", ["scale/scale_scaling_type"])
	_add_res_edit_source_array("mesh/mesh_LOD_variants", "mesh/selected_for_edit_resource")


func _create_input_field(__base_control:Control, __resource_previewer, prop:String) -> UI_InputField:
	_base_control = __base_control
	_resource_previewer = __resource_previewer
	
	var input_field:UI_InputField = null
	match prop:
		"mesh/mesh_LOD_variants":
			var accepted_classes := ["Greenhouse_LODVariant", "PackedScene"]
			accepted_classes.append_array(Globals.MESH_CLASSES)
			var settings := {
				"add_create_inst_button": true,
				"_base_control": _base_control,
				"accepted_classes": accepted_classes,
				"element_display_size": 75 * FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/greenhouse_thumbnail_scale", 1.0),
				"element_interaction_flags": UI_IF_ThumbnailArray.PRESET_LOD_VARIANT,
				"_resource_previewer": _resource_previewer,
				}
			input_field = UI_IF_ThumbnailArray.new(mesh_LOD_variants, "LOD Variants", prop, settings)
		"mesh/selected_for_edit_resource":
			var settings := {"_base_control": _base_control, "_resource_previewer": _resource_previewer, "label_visibility": false, "tab": 1}
			input_field = UI_IF_Object.new(selected_for_edit_resource, "LOD Variant", prop, settings)
		"mesh/mesh_LOD_max_distance":
			var max_value = FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/plant_max_distance_slider_max_value", 1000.0)
			var settings := {"min": 0.0, "max": max_value,  "step": 0.01,  "allow_greater": true,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(mesh_LOD_max_distance, "LOD Max Distance", prop, settings)
		"mesh/mesh_LOD_kill_distance":
			var max_value = FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/plant_kill_distance_slider_max_value", 2000.0)
			var settings := {"min": -1.0, "max": max_value,  "step": 0.01,  "allow_greater": true,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(mesh_LOD_kill_distance, "LOD Kill Distance", prop, settings)
		#======================================================
		"mesh/mesh_LOD_max_capacity":
			input_field = UI_IF_IntLineEdit.new(mesh_LOD_max_capacity, "Max chunk capacity", prop)
		"mesh/mesh_LOD_min_size":
			var max_value = FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/octree_min_node_size_slider_max_value", 500.0)
			var settings := {"min": 0.0, "max": max_value,  "step": 0.01,  "allow_greater": true,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(mesh_LOD_min_size, "Min node size", prop, settings)
		"octree/octree_reconfigure_button":
			var bound_input_fields:Array = create_input_fields(
				_base_control, _resource_previewer, ["mesh/mesh_LOD_max_capacity", "mesh/mesh_LOD_min_size"])
			var settings := {"button_text": "Configure Octree", "_base_control": _base_control, "bound_input_fields": bound_input_fields}
			input_field = UI_IF_ApplyChanges.new(octree_reconfigure_button, "Octree Configuration", prop, settings)
			input_field.connect("applied_changes", self, "on_dialog_if_applied_changes", [input_field])
			input_field.connect("cancelled_changes", self, "on_dialog_if_cancelled_changes", [input_field])
		"octree/octree_recenter_button":
			var settings := {"button_text": "Recenter Octree"}
			input_field = UI_IF_Button.new(octree_recenter_button, "Octree Centring", prop, settings)
			input_field.connect("pressed", self, "on_if_button", [input_field])
		#======================================================
		"density/density_per_units":
			var max_value = FunLib.get_setting_safe("dreadpons_spatial_gardener/input_and_ui/plant_density_slider_max_value", 2000.0)
			var settings := {"min": 0.0, "max": max_value,  "step": 0.01,  "allow_greater": true,  "allow_lesser": false,}
			var field_name = "Plants Per %d Unit" % [Globals.PLANT_DENSITY_UNITS]
			if Globals.PLANT_DENSITY_UNITS != 1:
				field_name += "s"
			input_field = UI_IF_RealSlider.new(density_per_units, field_name, prop, settings)
		#======================================================
		"scale/scale_scaling_type":
			var settings := {"enum_list": FunLib.capitalize_string_array(ScalingType.keys())}
			input_field = UI_IF_Enum.new(scale_scaling_type, "Scaling Type", prop, settings)
		"scale/scale_range":
			var settings := {
				"is_range": true,
				"value_count": 3,
				"representation_type": UI_IF_MultiRange.RepresentationType.VECTOR,
				}
			input_field = UI_IF_MultiRange.new(scale_range, "Random Scale Range", prop, settings)
		#======================================================
		"up_vector/up_vector_primary_type":
			var settings := {"enum_list": FunLib.capitalize_string_array(DirectionVectorType.keys())}
			input_field = UI_IF_Enum.new(up_vector_primary_type, "Primary Up-Vector", prop, settings)
		"up_vector/up_vector_primary":
			var settings := {
				"is_range": false,
				"value_count": 3,
				"representation_type": UI_IF_MultiRange.RepresentationType.VECTOR,
				}
			input_field = UI_IF_MultiRange.new(up_vector_primary, "Up-Vector Primary", prop, settings)
#			input_field.add_tracked_property("up_vector/up_vector_primary_type", DirectionVectorType.CUSTOM, up_vector_primary_type)
#			input_field.set_visibility_is_tracked(true)
		"up_vector/up_vector_secondary_type":
			var settings := {"enum_list": FunLib.capitalize_string_array(DirectionVectorType.keys())}
			input_field = UI_IF_Enum.new(up_vector_secondary_type, "Secondary Up-Vector", prop, settings)
		"up_vector/up_vector_secondary":
			var settings := {
				"is_range": false,
				"value_count": 3,
				"representation_type": UI_IF_MultiRange.RepresentationType.VECTOR,
				}
			input_field = UI_IF_MultiRange.new(up_vector_secondary, "Up-Vector Secondary", prop, settings)
#			input_field.add_tracked_property("up_vector/up_vector_secondary_type", DirectionVectorType.CUSTOM, up_vector_secondary_type)
#			input_field.set_visibility_is_tracked(true)
		"up_vector/up_vector_blending":
			var settings := {"min": 0.0, "max": 1.0,  "step": 0.01,  "allow_greater": false,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(up_vector_blending, "Up-Vector Blending", prop, settings)
		#======================================================
		"fwd_vector/fwd_vector_primary_type":
			var settings := {"enum_list": FunLib.capitalize_string_array(DirectionVectorType.keys())}
			input_field = UI_IF_Enum.new(fwd_vector_primary_type, "Primary Forward-Vector", prop, settings)
		"fwd_vector/fwd_vector_primary":
			var settings := {
				"is_range": false,
				"value_count": 3,
				"representation_type": UI_IF_MultiRange.RepresentationType.VECTOR,
				}
			input_field = UI_IF_MultiRange.new(fwd_vector_primary, "Forward-Vector Primary", prop, settings)
#			input_field.add_tracked_property("fwd_vector/fwd_vector_primary_type", DirectionVectorType.CUSTOM, fwd_vector_primary_type)
#			input_field.set_visibility_is_tracked(true)
		"fwd_vector/fwd_vector_secondary_type":
			var settings := {"enum_list": FunLib.capitalize_string_array(DirectionVectorType.keys())}
			input_field = UI_IF_Enum.new(fwd_vector_secondary_type, "Secondary Forward-Vector", prop, settings)
		"fwd_vector/fwd_vector_secondary":
			var settings := {
				"is_range": false,
				"value_count": 3,
				"representation_type": UI_IF_MultiRange.RepresentationType.VECTOR,
				}
			input_field = UI_IF_MultiRange.new(fwd_vector_secondary, "Forward-Vector Secondary", prop, settings)
#			input_field.add_tracked_property("fwd_vector/fwd_vector_secondary_type", DirectionVectorType.CUSTOM, fwd_vector_secondary_type)
#			input_field.set_visibility_is_tracked(true)
		"fwd_vector/fwd_vector_blending":
			var settings := {"min": 0.0, "max": 1.0,  "step": 0.01,  "allow_greater": false,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(fwd_vector_blending, "Forward-Vector Blending", prop, settings)
		#======================================================
		"offset/offset_y_range":
			var settings := {
				"is_range": true,
				"value_count": 1,
				"representation_type": UI_IF_MultiRange.RepresentationType.VALUE,
				}
			input_field = UI_IF_MultiRange.new(offset_y_range, "Random Offset Range Y", prop, settings)
		"offset/offset_jitter_fraction":
			var settings := {"min": 0.0, "max": 1.0,  "step": 0.01,  "allow_greater": false,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(offset_jitter_fraction, "Offset Jitter Fraction", prop, settings)
		#======================================================
		"rotation/rotation_random_y":
			var settings := {"min": 0.0, "max": 180.0,  "step": 0.01,  "allow_greater": false,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(rotation_random_y, "Random Rotation Y", prop, settings)
		"rotation/rotation_random_x":
			var settings := {"min": 0.0, "max": 180.0,  "step": 0.01,  "allow_greater": false,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(rotation_random_x, "Random Rotation X", prop, settings)
		"rotation/rotation_random_z":
			var settings := {"min": 0.0, "max": 180.0,  "step": 0.01,  "allow_greater": false,  "allow_lesser": false,}
			input_field = UI_IF_RealSlider.new(rotation_random_x, "Random Rotation Z", prop, settings)
		#======================================================
		"slope/slope_allowed_range":
			var settings := {
				"is_range": true,
				"value_count": 1,
				"representation_type": UI_IF_MultiRange.RepresentationType.VALUE,
				}
			input_field = UI_IF_MultiRange.new(slope_allowed_range, "Allowed Slope Range", prop, settings)
		#======================================================
		"import_export/import_button":
			var settings := {"button_text": "Import"}
			input_field = UI_IF_Button.new(import_export_import_button, "Import Transforms", prop, settings)
			input_field.connect("pressed", self, "on_if_button", [input_field])
		"import_export/export_button":
			var settings := {"button_text": "Export"}
			input_field = UI_IF_Button.new(import_export_export_button, "Export Transforms", prop, settings)
			input_field.connect("pressed", self, "on_if_button", [input_field])
	
	return input_field




#-------------------------------------------------------------------------------
# Signal forwarding
#-------------------------------------------------------------------------------


func on_changed_LOD_variant():
	emit_changed()


func reconfigure_octree():
	emit_signal("req_octree_reconfigure")




#-------------------------------------------------------------------------------
# Prop actions
#-------------------------------------------------------------------------------


# A prop action was executed on one of the LOD variants
# If a mesh was changed - update thumbnail
# If a spawned spatial was changed - spawn or deelte them
func on_prop_action_executed_on_LOD_variant(prop_action, final_val, LOD_variant):
	var index = mesh_LOD_variants.find(LOD_variant)
	var update_thumbnail = prop_action.prop == "mesh"
	if update_thumbnail:
		emit_signal("prop_action_executed", PA_ArraySet.new("mesh/mesh_LOD_variants", LOD_variant, index), mesh_LOD_variants)
	emit_signal("prop_action_executed_on_LOD_variant", prop_action, final_val, LOD_variant)




#-------------------------------------------------------------------------------
# UI management
#-------------------------------------------------------------------------------


# Handle changes applied by input field dialog
func on_dialog_if_applied_changes(initial_values:Array, final_values:Array, input_field:UI_InputField):
	match input_field.prop_name:
		"octree/octree_reconfigure_button":
			_undo_redo.create_action("Reconfigure Octree")
			_undo_redo.add_do_method(input_field, "set_values", final_values)
			_undo_redo.add_do_method(self, "reconfigure_octree")
			_undo_redo.add_undo_method(input_field, "set_values", initial_values)
			_undo_redo.add_undo_method(self, "reconfigure_octree")
			_undo_redo.commit_action()


# Handle changes cancelled by input field dialog
func on_dialog_if_cancelled_changes(input_field:UI_InputField):
	pass


# Handle an input field button press
func on_if_button(input_field:UI_InputField):
	match input_field.prop_name:
		"octree/octree_recenter_button":
			emit_signal("req_octree_recenter")
		"import_export/import_button":
			emit_signal("req_import_transforms")
		"import_export/export_button":
			emit_signal("req_export_transforms")




#-------------------------------------------------------------------------------
# Property management
#-------------------------------------------------------------------------------


func _modify_prop(prop:String, val):
	match prop:
		"mesh/mesh_LOD_variants":
			# TODO retain Greenhouse_LODVariant if it already exists when drag-and-dropping a .mesh or a .tscn resource
			for i in range(0, val.size()):
				if !(val[i] is Greenhouse_LODVariant):
					val[i] = Greenhouse_LODVariant.new()
				
				FunLib.ensure_signal(val[i], "changed", self, "on_changed_LOD_variant")
				FunLib.ensure_signal(val[i], "prop_action_executed", self, "on_prop_action_executed_on_LOD_variant", [val[i]])
				
				if val[i]._undo_redo != _undo_redo:
					val[i].set_undo_redo(_undo_redo)
		"scale/scale_range":
			val = val.duplicate()
			match scale_scaling_type:
				ScalingType.UNIFORM:
					val[0].y = val[0].x
					val[0].z = val[0].x
					val[1].y = val[1].x
					val[1].z = val[1].x
				ScalingType.LOCK_XY:
					val[0].y = val[0].x
					val[1].y = val[1].x
				ScalingType.LOCK_XZ:
					val[0].z = val[0].x
					val[1].z = val[1].x
				ScalingType.LOCK_ZY:
					val[0].z = val[0].y
					val[1].z = val[1].y
		"mesh/mesh_LOD_kill_distance":
			if val < mesh_LOD_max_distance && val >= 0:
				val = mesh_LOD_max_distance
#		"mesh/mesh_LOD_max_distance":
#			if mesh_LOD_kill_distance < val:
#				mesh_LOD_kill_distance = val
		"slope/slope_allowed_range":
			for i in range(0, val.size()):
				var element = val[i]
				if element < 0.0:
					val[i] = 0.0
				elif element > 180.0:
					val[i] = 180.0
	return val


# A special override just for the plants
# To allow drag-and-dropping .mesh and .tscn instead of editing a resource
func request_prop_action(prop_action:PropAction):
	match prop_action.prop:
		"mesh/mesh_LOD_variants":
			if prop_action is PA_ArraySet:
				
				var new_prop_action = null
				if prop_action.val is PackedScene:
					new_prop_action = PA_PropSet.new("spawned_spatial", prop_action.val)
				else:
					for mesh_class in Globals.MESH_CLASSES:
						if FunLib.obj_is_class_string(prop_action.val, mesh_class):
							new_prop_action = PA_PropSet.new("mesh", prop_action.val)
							break
				
				if new_prop_action != null:
					mesh_LOD_variants[prop_action.index].request_prop_action(new_prop_action)
					return
	
	on_prop_action_requested(prop_action)




#-------------------------------------------------------------------------------
# Property export
#-------------------------------------------------------------------------------


func set_undo_redo(val:UndoRedo):
	.set_undo_redo(val)
	for LOD_variant in mesh_LOD_variants:
		LOD_variant.set_undo_redo(_undo_redo)


func _set(prop, val):
	var return_val = true
	val = _modify_prop(prop, val)
	
	match prop:
		"mesh/mesh_LOD_variants":
			mesh_LOD_variants = val
		"mesh/selected_for_edit_resource":
			selected_for_edit_resource = val
		"mesh/mesh_LOD_max_distance":
			mesh_LOD_max_distance = val
		"mesh/mesh_LOD_kill_distance":
			mesh_LOD_kill_distance = val
		"mesh/mesh_LOD_max_capacity":
			mesh_LOD_max_capacity = val
		"mesh/mesh_LOD_min_size":
			mesh_LOD_min_size = val
		"octree/octree_reconfigure_button":
			octree_reconfigure_button = val
		"octree/octree_recenter_button":
			octree_recenter_button = val
		
		"density/density_per_units":
			density_per_units = val
		
		"scale/scale_scaling_type":
			scale_scaling_type = val
			_emit_property_list_changed_notify()
		"scale/scale_range":
			scale_range = val
		
		"up_vector/up_vector_primary_type":
			up_vector_primary_type = val
			_emit_property_list_changed_notify()
		"up_vector/up_vector_primary":
			up_vector_primary = val
		"up_vector/up_vector_secondary_type":
			up_vector_secondary_type = val
			_emit_property_list_changed_notify()
		"up_vector/up_vector_secondary":
			up_vector_secondary = val
		"up_vector/up_vector_blending":
			up_vector_blending = val
		
		"fwd_vector/fwd_vector_primary_type":
			fwd_vector_primary_type = val
			_emit_property_list_changed_notify()
		"fwd_vector/fwd_vector_primary":
			fwd_vector_primary = val
		"fwd_vector/fwd_vector_secondary_type":
			fwd_vector_secondary_type = val
			_emit_property_list_changed_notify()
		"fwd_vector/fwd_vector_secondary":
			fwd_vector_secondary = val
		"fwd_vector/fwd_vector_blending":
			fwd_vector_blending = val
		
		"offset/offset_y_range":
			offset_y_range = val
		"offset/offset_jitter_fraction":
			offset_jitter_fraction = val
		
		"rotation/rotation_random_y":
			rotation_random_y = val
		"rotation/rotation_random_x":
			rotation_random_x = val
		"rotation/rotation_random_z":
			rotation_random_z = val
		
		"slope/slope_allowed_range":
			slope_allowed_range = val
		
		"import_export/import_button":
			import_export_import_button = val
		"import_export/export_button":
			import_export_export_button = val
		_:
			return_val = false
	
	if return_val:
		emit_changed()
	return return_val


func _get(property):
	match property:
		"mesh/mesh_LOD_variants":
			return mesh_LOD_variants
		"mesh/selected_for_edit_resource":
			return selected_for_edit_resource
		"mesh/mesh_LOD_max_distance":
			return mesh_LOD_max_distance
		"mesh/mesh_LOD_kill_distance":
			return mesh_LOD_kill_distance
		"mesh/mesh_LOD_max_capacity":
			return mesh_LOD_max_capacity
		"mesh/mesh_LOD_min_size":
			return mesh_LOD_min_size
		"octree/octree_reconfigure_button":
			return octree_reconfigure_button
		"octree/octree_recenter_button":
			return octree_recenter_button
		
		"density/density_per_units":
			return density_per_units
		
		"scale/scale_scaling_type":
			return scale_scaling_type
		"scale/scale_range":
			return scale_range
		
		"up_vector/up_vector_primary_type":
			return up_vector_primary_type
		"up_vector/up_vector_primary":
			return up_vector_primary
		"up_vector/up_vector_secondary_type":
			return up_vector_secondary_type
		"up_vector/up_vector_secondary":
			return up_vector_secondary
		"up_vector/up_vector_blending":
			return up_vector_blending
		
		"fwd_vector/fwd_vector_primary_type":
			return fwd_vector_primary_type
		"fwd_vector/fwd_vector_primary":
			return fwd_vector_primary
		"fwd_vector/fwd_vector_secondary_type":
			return fwd_vector_secondary_type
		"fwd_vector/fwd_vector_secondary":
			return fwd_vector_secondary
		"fwd_vector/fwd_vector_blending":
			return fwd_vector_blending
		
		"offset/offset_y_range":
			return offset_y_range
		"offset/offset_jitter_fraction":
			return offset_jitter_fraction
		
		"rotation/rotation_random_y":
			return rotation_random_y
		"rotation/rotation_random_x":
			return rotation_random_x
		"rotation/rotation_random_z":
			return rotation_random_z
		
		"slope/slope_allowed_range":
			return slope_allowed_range
		
		"import_export/import_button":
			return import_export_import_button
		"import_export/export_button":
			return import_export_export_button
	
	return null


func _filter_prop_dictionary(prop_dict: Dictionary) -> Dictionary:
	var props_to_hide := []

	if up_vector_primary_type != DirectionVectorType.CUSTOM:
		props_to_hide.append("up_vector/up_vector_primary")
	if up_vector_secondary_type != DirectionVectorType.CUSTOM:
		props_to_hide.append("up_vector/up_vector_secondary")
	if fwd_vector_primary_type != DirectionVectorType.CUSTOM:
		props_to_hide.append("fwd_vector/fwd_vector_primary")
	if fwd_vector_secondary_type != DirectionVectorType.CUSTOM:
		props_to_hide.append("fwd_vector/fwd_vector_secondary")
	
	if up_vector_primary_type == up_vector_secondary_type && up_vector_primary_type != DirectionVectorType.CUSTOM:
		props_to_hide.append("up_vector/up_vector_blending")
	if fwd_vector_primary_type == fwd_vector_secondary_type && fwd_vector_primary_type != DirectionVectorType.CUSTOM:
		props_to_hide.append("fwd_vector/fwd_vector_blending")
	
	for prop in props_to_hide:
		prop_dict[prop].usage = PROPERTY_USAGE_NOEDITOR
	
	return prop_dict


func _get_prop_dictionary():
	return {
		"mesh/mesh_LOD_variants":
		{
			"name": "mesh/mesh_LOD_variants",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"mesh/selected_for_edit_resource":
		{
			"name": "mesh/selected_for_edit_resource",
			"type": TYPE_OBJECT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"mesh/mesh_LOD_max_distance":
		{
			"name": "mesh/mesh_LOD_max_distance",
			"type": TYPE_REAL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"mesh/mesh_LOD_kill_distance":
		{
			"name": "mesh/mesh_LOD_kill_distance",
			"type": TYPE_REAL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"mesh/mesh_LOD_max_capacity":
		{
			"name": "mesh/mesh_LOD_max_capacity",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"mesh/mesh_LOD_min_size":
		{
			"name": "mesh/mesh_LOD_min_size",
			"type": TYPE_REAL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"octree/octree_reconfigure_button":
		{
			"name": "octree/octree_reconfigure_button",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"octree/octree_recenter_button":
		{
			"name": "octree/octree_recenter_button",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		#======================================================
		"density/density_per_units":
		{
			"name": "density/density_per_units",
			"type": TYPE_REAL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		#======================================================
		"scale/scale_scaling_type":
		{
			"name": "scale/scale_scaling_type",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Uniform,Free,Lock XY,Lock ZY,Lock XZ"
		},
		"scale/scale_range":
		{
			"name": "scale/scale_range",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		#======================================================
		"up_vector/up_vector_primary_type":
		{
			"name": "up_vector/up_vector_primary_type",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Unused,World X,World Y,World Z,Normal,Custom"
		},
		"up_vector/up_vector_primary":
		{
			"name": "up_vector/up_vector_primary",
			"type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"up_vector/up_vector_secondary_type":
		{
			"name": "up_vector/up_vector_secondary_type",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Unused,World X,World Y,World Z,Normal,Custom"
		},
		"up_vector/up_vector_secondary":
		{
			"name": "up_vector/up_vector_secondary",
			"type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"up_vector/up_vector_blending":
		{
			"name": "up_vector/up_vector_blending",
			"type": TYPE_REAL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1.0"
		},
		#======================================================
		"fwd_vector/fwd_vector_primary_type":
		{
			"name": "fwd_vector/fwd_vector_primary_type",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Unused,World X,World Y,World Z,Normal,Custom"
		},
		"fwd_vector/fwd_vector_primary":
		{
			"name": "fwd_vector/fwd_vector_primary",
			"type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"fwd_vector/fwd_vector_secondary_type":
		{
			"name": "fwd_vector/fwd_vector_secondary_type",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Unused,World X,World Y,World Z,Normal,Custom"
		},
		"fwd_vector/fwd_vector_secondary":
		{
			"name": "fwd_vector/fwd_vector_secondary",
			"type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"fwd_vector/fwd_vector_blending":
		{
			"name": "fwd_vector/fwd_vector_blending",
			"type": TYPE_REAL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1.0"
		},
		#======================================================
		"offset/offset_y_range":
		{
			"name": "offset/offset_y_range",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"offset/offset_jitter_fraction":
		{
			"name": "offset/offset_jitter_fraction",
			"type": TYPE_REAL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		#======================================================
		"rotation/rotation_random_y":
		{
			"name": "rotation/rotation_random_y",
			"type": TYPE_REAL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,180.0"
		},
		"rotation/rotation_random_x":
		{
			"name": "rotation/rotation_random_x",
			"type": TYPE_REAL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,180.0"
		},
		"rotation/rotation_random_z":
		{
			"name": "rotation/rotation_random_z",
			"type": TYPE_REAL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,180.0"
		},
		#======================================================
		"slope/slope_allowed_range":
		{
			"name": "slope/slope_allowed_range",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		#======================================================
		"import_export/import_button":
		{
			"name": "import_export/export_button",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"import_export/export_button":
		{
			"name": "import_export/export_button",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
	}


func _fix_duplicate_signals(copy):
	copy._modify_prop("mesh/mesh_LOD_variants", copy.mesh_LOD_variants)
	copy.selected_for_edit_resource = null


func get_prop_tooltip(prop:String) -> String:
	match prop:
		"mesh/mesh_LOD_variants":
			return "The array of Level Of Detail resources that's used to swap meshes depending on distance to the camera\n" \
				+ "This allows to have high-detailed meshes when the player is close, but low-detailed when they're far way\n" \
				+ "This technique is used to optimize performance\n" \
				+ "\n" \
				+ "This property supports drag-and-drop of Greenhouse_LODVariant resources\n" \
				+ "As well as .mesh and .tscn resources. In this case, Greenhouse_LODVariant will be created automatically"
		"mesh/selected_for_edit_resource":
			return "The plant currently selected for editing"
		"mesh/mesh_LOD_max_distance":
			return "The distance after which the lowest-detailed LOD (last one in the array) is chosen\n" \
				+ "LODs in-between are spread evenly across this distance\n"
		"mesh/mesh_LOD_kill_distance":
			return "The distance after which the mesh and it's Spawned Spatial are removed entirely\n" \
				+ "Used to save perfomance by rejecting small objects like grass or rocks at big distances\n" \
				+ "A default value of '-1' disables this behavior (the object will be active forever)"
		"mesh/mesh_LOD_max_capacity":
			return "The soft limit of how many instances can an octree node contain before it is subdivided\n" \
				+ "This can be bypassed by the node minimum size"
		"mesh/mesh_LOD_min_size":
			return "The hard limit of how small an octree node can get\n" \
				+ "If both capacity and size limits are approached, only the size will be honored\n" \
				+ "I.e. octree nodes will contain more instances than their capacity allows"
		"octree/octree_reconfigure_button":
			return "The button to reconfigure octree nodes' capacity and minimum size"
		"octree/octree_recenter_button":
			return "The button to recenter the entire octree according to the space it's instances occupy\n" \
				+ "This operation is recommended once you finished painting your plants\n" \
				+ "As it optimizes both the performance (slightly) and the LOD switching behavior (more importantly)"
		
		"density/density_per_units":
			return "How many plants will be placed in a square of %dx%d units\n" % [Globals.PLANT_DENSITY_UNITS, Globals.PLANT_DENSITY_UNITS] \
				+ "This is an approximate amount and it should not be taken as an absolute\n"
		
		"scale/scale_scaling_type":
			return "Defines the rules for scaling randomization\n" \
				+ "By default it scales uniformly, meaning all axes will have the same value\n" \
				+ "You can remove the lock entirely and allow each axis to have it's own randomized value (typically results in wonky-looking meshes)\n" \
				+ "Or you can lock one of the planes\n" \
				+ "e.g. XZ-lock with make horizontal scaling uniform (plants won't appear twisted), but allow varying vertical scaling"
		"scale/scale_range":
			return "The range in which scaling is randomized. Honors the scaling type\n" \
				+ "When any scaling lock is active (including Uniform), only the first variable can be edited, the rest will update automatically"
		
		"up_vector/up_vector_primary_type":
			return "Defines the source for the up vector used to orient our plant\n" \
				+ "Can use world-based vectors, normals of the surface or a custom vector in world-space"
		"up_vector/up_vector_primary":
			return "The custom value to be used as primary up vector"
		"up_vector/up_vector_secondary_type":
			return "Defines the source for second vector to be used in blending/interpolation\n" \
				+ "Can use world-based vectors, normals of the surface or a custom vector in world-space"
		"up_vector/up_vector_secondary":
			return "The custom value to be used as secondary up vector"
		"up_vector/up_vector_blending":
			return "How much we blend between our vectors\n" \
				+ "0.0 - use primary, 0.5 - use in-between the two, 1.0 - use secondary and so on\n" \
				+ "Is used to specify the main orientation for our plant and then a small inclination towards something\n" \
				+ "E.g. a tree that grows upward, but is slightly tilted with it's surface"
		
		"fwd_vector/fwd_vector_primary_type":
			return "Defines the source for the forward vector used to orient our plant\n" \
				+ "Can use world-based vectors, normals of the surface or a custom vector in world-space"
		"fwd_vector/fwd_vector_primary":
			return "The custom value to be used as primary forward vector"
		"fwd_vector/fwd_vector_secondary_type":
			return "Defines the source for second vector to be used in blending/interpolation\n" \
				+ "Can use world-based vectors, normals of the surface or a custom vector in world-space"
		"fwd_vector/fwd_vector_secondary":
			return "The custom value to be used as secondary forward vector"
		"fwd_vector/fwd_vector_blending":
			return "How much we blend between our vectors\n" \
				+ "0.0 - use primary, 0.5 - use in-between the two, 1.0 - use secondary and so on\n" \
				+ "Is used to specify the main orientation for our plant and then a small inclination towards something\n" \
				+ "E.g. a signpost that points forward in world space, but is slightly tilted to it's target"
		
		"offset/offset_y_range":
			return "The range of random vertical offset in local space\n" \
				+ "Used to hide things like roots below the surface"
		"offset/offset_jitter_fraction":
			return "The random 'cell offset' for each instance\n" \
				+ "All instances are placed on a virtual grid, and with a jitter of 0.0 will appear placed using a ruler\n" \
				+ "Jitter specifies how far in local space of each cell can an instance be offset\n" \
				+ "E.g. 0.0 - instance in the center, 0.5 - instance can be halfway to the cell's border, 1.0 - instance can appear on the border\n" \
				+ "The values of 0.0 and 1.0 should generally be avoided"
		
		"rotation/rotation_random_y":
			return "The range of random rotation on Y axis (Yaw)\n" \
				+ "E.g. 45 means it can be rotated to a random angle between 45 degress clokwise and counter clockwise"
		"rotation/rotation_random_x":
			return "The range of random rotation on X axis (Pitch)\n" \
				+ "E.g. 45 means it can be rotated to a random angle between 45 degress clokwise and counter clockwise"
		"rotation/rotation_random_z":
			return "The range of random rotation on Z axis (Roll)\n" \
				+ "E.g. 45 means it can be rotated to a random angle between 45 degress clokwise and counter clockwise"
		
		"slope/slope_allowed_range":
			return "The range of slopes (in degrees) where our plant can be placed\n" \
				+ "Can be used to avoid placing plants on steep slopes or vertical walls\n" \
				+ "\n" \
				+ "NOTE: slope is calculated in relation to the Primary Up Vector\n" \
				+ "If you wish to align your plant to Surface Normal and use the slope\n" \
				+ "Set Primary Up Vector to World Y, secondary to Normal and just blend all the way to the secondary vector (blend = 1.0)" 
		
		"import_export/import_button":
			return "The button to import instance transforms for the current plant inside a current Gardener\n" \
				+ "To then import them to a different scene\n" \
				+ "Or when switching between plugin versions (whenever necessary)\n" \
				+ "Instances are ADDED to the existing ones; to replace you'll need to manually erase the old instances first\n" \
				+ "\n" \
				+ "NOTE: import recreates your octree nodes anew and they won't be the same\n" \
				+ "(but they were killed already by an export operation to begin with)\n" \
				+ "Most of the time this can be ignored since you likely Rebuild/Recenter your octrees on a regular basis anyway"
		"import_export/export_button":
			return "The button to export all instance transforms of current plant inside a current Gardener\n" \
				+ "To import them to a different scene\n" \
				+ "Or when switching between plugin versions (whenever necessary)\n" \
				+ "\n" \
				+ "NOTE: export kills whatever octree nodes you have\n" \
				+ "(and import recreates them anew but they won't be the same)\n" \
				+ "Most of the time this can be ignored since you likely Rebuild/Recenter your octrees on a regular basis anyway"
	
	return ""
