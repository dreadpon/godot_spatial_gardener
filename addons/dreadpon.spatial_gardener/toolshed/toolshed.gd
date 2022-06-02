tool
extends "../utility/input_field_resource/input_field_resource.gd"


#-------------------------------------------------------------------------------
# The manager of all brush types for a given Gardener
# Handles interfacing between Toolshed_Brush, UI and plant painting
#-------------------------------------------------------------------------------


const Toolshed_Brush = preload("toolshed_brush.gd")
const ThemeAdapter = preload("../controls/theme_adapter.gd")


var brushes:Array = []
var active_brush:Toolshed_Brush = null
var brush_panel:TabContainer = null

var _base_control:Control = null
var _resource_previewer = null


signal prop_action_executed_on_brush(prop_action, final_val, brush)




#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


func _init(__brushes:Array = []).():
	set_meta("class", "Toolshed")
	resource_name = "Toolshed"
	
	brushes = __brushes
	_add_prop_dependency("brush/active_brush", ["brush/brushes"])


# The UI is created here because we need to manage it afterwards 
# And I see no reason to get lost in a signal spaghetti of delegating it
func create_ui(__base_control:Control, __resource_previewer):
	_base_control = __base_control
	_resource_previewer = __resource_previewer
	
	brush_panel = TabContainer.new()
	brush_panel.name = "brush_panel"
	brush_panel.tab_align = TabContainer.ALIGN_LEFT
	brush_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brush_panel.set_anchors_preset(Control.PRESET_WIDE)
	
	for brush in brushes:
		var scroll_container := ScrollContainer.new()
		scroll_container.scroll_horizontal_enabled = false
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.name = FunLib.capitalize_string_array(brush.BrushType.keys())[brush.behavior_brush_type]
		
		var margin_container := MarginContainer.new()
		margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin_container.name = "margin_container"
		margin_container.set_anchors_preset(Control.PRESET_WIDE)
		
		var box_container := VBoxContainer.new()
		box_container.name = "box_container"
		box_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		for input_field in brush.create_input_fields(_base_control, _resource_previewer):
			box_container.add_child(input_field)
		
		brush_panel.add_child(scroll_container)
		scroll_container.add_child(margin_container)
		margin_container.add_child(box_container)
		ThemeAdapter.assign_node_type(margin_container, "ExternalMargin")
	
	if brushes.size() > 0:
		brush_panel.current_tab = brushes.find(active_brush)
	brush_panel.connect("tab_changed", self, "on_active_brush_tab_changed")
	
	return brush_panel


func _fix_duplicate_signals(copy):
	copy._modify_prop("brush/brushes", copy.brushes)
	copy.active_brush = copy.brushes[0]




#-------------------------------------------------------------------------------
# Input
#-------------------------------------------------------------------------------


func forwarded_input(camera, event):
	var handled := false
	
	var index_tab = -1
	
	if event is InputEventKey && !event.pressed:
		var index_map := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
		index_tab = index_map.find(event.scancode)
		
		if index_tab >= 0 && index_tab < brushes.size():
			handled = true
			on_active_brush_tab_changed(index_tab)
			return



#-------------------------------------------------------------------------------
# Syncing the Toolshed with it's UI
#-------------------------------------------------------------------------------


func on_active_brush_tab_changed(active_tab):
	var prop_action:PropAction = PA_PropSet.new("brush/active_brush", brushes[active_tab])
	request_prop_action(prop_action)


func on_prop_action_executed(prop_action:PropAction, final_val):
	if prop_action is PA_PropSet:
		if prop_action.prop == "brush/active_brush":
			if brush_panel:
				brush_panel.disconnect("tab_changed", self, "on_active_brush_tab_changed")
				brush_panel.current_tab = brushes.find(final_val)
				brush_panel.connect("tab_changed", self, "on_active_brush_tab_changed")




#-------------------------------------------------------------------------------
# Broadcast changes within the brushes themselves
#-------------------------------------------------------------------------------


func on_changed_brush():
	emit_changed()


func on_prop_action_executed_on_brush(prop_action:PropAction, final_val, brush):
	emit_signal("prop_action_executed_on_brush", prop_action, final_val, brush)




#-------------------------------------------------------------------------------
# Property export
#-------------------------------------------------------------------------------


func set_undo_redo(val:UndoRedo):
	.set_undo_redo(val)
	for brush in brushes:
		brush.set_undo_redo(_undo_redo)


func _modify_prop(prop:String, val):
	match prop:
		"brush/brushes":
			for i in range(0, val.size()):
				if !(val[i] is Toolshed_Brush):
					val[i] = Toolshed_Brush.new()
				
				FunLib.ensure_signal(val[i], "changed", self, "on_changed_brush")
				FunLib.ensure_signal(val[i], "prop_action_executed", self, "on_prop_action_executed_on_brush", [val[i]])
				
				if val[i]._undo_redo != _undo_redo:
					val[i].set_undo_redo(_undo_redo)
		"brush/active_brush":
			if !brushes.has(val):
				if brushes.size() > 0:
					val = brushes[0]
				else:
					val = null
	
	return val


func _get(property):
	match property:
		"brush/brushes":
			return brushes
		"brush/active_brush":
			return active_brush
	
	return null


func _set(prop, val):
	var return_val = true
	val = _modify_prop(prop, val)
	
	match prop:
		"brush/brushes":
			brushes = val
		"brush/active_brush":
			active_brush = val
		_:
			return_val = false
	
	if return_val:
		emit_changed()
	return return_val


func _get_prop_dictionary():
	return {
		"brush/brushes":
		{
			"name": "brush/brushes",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"brush/active_brush":
		{
			"name": "brush/active_brush",
			"type": TYPE_OBJECT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
	}


func _get_property_list():
	var prop_dict = _get_prop_dictionary()
	var props := [
		prop_dict["brush/brushes"],
		prop_dict["brush/active_brush"],
	]
	
	return props


func get_prop_tooltip(prop:String) -> String:
	match prop:
		"brush/brushes":
			return "The list of all brushes available in this toolshed"
		"brush/active_brush":
			return "The brush that is currently selected and used in the painting process"
	return ""
