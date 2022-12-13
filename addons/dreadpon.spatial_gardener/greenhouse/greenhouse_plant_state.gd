tool
extends "../utility/input_field_resource/input_field_resource.gd"


#-------------------------------------------------------------------------------
# A middle-man between the plant and the UI/painting/placement logic
#-------------------------------------------------------------------------------


const Greenhouse_Plant = preload("greenhouse_plant.gd")


var plant_brush_active:bool = false
var plant_label:String = ''
var plant:Greenhouse_Plant = null


signal prop_action_executed_on_plant(prop_action, final_val, plant)
signal prop_action_executed_on_LOD_variant(prop_action, final_val, LOD_variant, plant)
signal req_octree_reconfigure(plant)
signal req_octree_recenter(plant)
signal req_import_transforms(plant)
signal req_export_transforms(plant)




#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


func _init().():
	set_meta("class", "Greenhouse_PlantState")
	resource_name = "Greenhouse_PlantState"
	# A workaround to trigger the initial creation of a plant
	_set("plant/plant", plant)




#-------------------------------------------------------------------------------
# Signal forwarding
#-------------------------------------------------------------------------------


func on_changed_plant():
	emit_changed()

func on_prop_action_executed_on_plant(prop_action, final_val, plant):
	emit_signal("prop_action_executed_on_plant", prop_action, final_val, plant)

func on_req_octree_reconfigure(plant):
	emit_signal("req_octree_reconfigure", plant)

func on_req_octree_recenter(plant):
	emit_signal("req_octree_recenter", plant)

func on_req_import_transforms(plant):
	emit_signal("req_import_transforms", plant)

func on_req_export_transforms(plant):
	emit_signal("req_export_transforms", plant)

func on_prop_action_executed_on_LOD_variant(prop_action, final_val, LOD_variant, plant):
	emit_signal("prop_action_executed_on_LOD_variant", prop_action, final_val, LOD_variant, plant)



#-------------------------------------------------------------------------------
# Property management
#-------------------------------------------------------------------------------


func _modify_prop(prop:String, val):
	match prop:
		"plant/plant":
			if !(val is Greenhouse_Plant):
				val = Greenhouse_Plant.new()
			
			FunLib.ensure_signal(val, "changed", self, "on_changed_plant")
			FunLib.ensure_signal(val, "prop_action_executed", self, "on_prop_action_executed_on_plant", [val])
			FunLib.ensure_signal(val, "prop_action_executed_on_LOD_variant", self, "on_prop_action_executed_on_LOD_variant", [val])
			FunLib.ensure_signal(val, "req_octree_reconfigure", self, "on_req_octree_reconfigure", [val])
			FunLib.ensure_signal(val, "req_octree_recenter", self, "on_req_octree_recenter", [val])
			FunLib.ensure_signal(val, "req_import_transforms", self, "on_req_import_transforms", [val])
			FunLib.ensure_signal(val, "req_export_transforms", self, "on_req_export_transforms", [val])
			
			if val._undo_redo != _undo_redo:
				val.set_undo_redo(_undo_redo)
	return val




#-------------------------------------------------------------------------------
# Property export
#-------------------------------------------------------------------------------


func set_undo_redo(val:UndoRedo):
	.set_undo_redo(val)
	plant.set_undo_redo(_undo_redo)


func _get(prop):
	match prop:
		"plant/plant_brush_active":
			return plant_brush_active
		"plant/plant_label":
			return plant_label
		"plant/plant":
			return plant
	
	return null


func _set(prop, val):
	var return_val = true
	val = _modify_prop(prop, val)
	
	match prop:
		"plant/plant_brush_active":
			plant_brush_active = val
		"plant/plant_label":
			plant_label = val
		"plant/plant":
			plant = val
		_:
			return_val = false
	
	if return_val:
		emit_changed()
	return return_val


func _get_prop_dictionary():
	return {
		"plant/plant_brush_active":
		{
			"name": "plant/plant_brush_active",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"plant/plant_label":
		{
			"name": "plant/plant_label",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"plant/plant":
		{
			"name": "plant/plant",
			"type": TYPE_OBJECT ,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE
		},
		}


func create_input_fields(_base_control:Control, _resource_previewer, whitelist:Array = []):
	if plant:
		return plant.create_input_fields(_base_control, _resource_previewer, whitelist)


func _fix_duplicate_signals(copy):
	copy._modify_prop("plant/plant", copy.plant)


func get_prop_tooltip(prop:String) -> String:
	match prop:
		"plant/plant_brush_active":
			return "The flag that defines if plant will be used during painting or not"
		"plant/plant_brush_active":
			return "The label to be displayed on top of the plant's thumbnail"
		"plant/plant":
			return "The contained plant itself"
	
	return ""
