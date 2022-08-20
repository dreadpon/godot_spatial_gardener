tool
extends "ui_input_field.gd"


#-------------------------------------------------------------------------------
# Shows a dialog with InputField controls when button is pressed
# InputField controls will be set with PA_PropSet if dialog was confirmed
# InputField controls will be reverted to initial values if dialog was cancelled
#-------------------------------------------------------------------------------


const UI_FoldableSection_SCN = preload('../side_panel/ui_foldable_section.tscn')

var margin_container:PanelContainer = null
var input_field_container:VBoxContainer = null
var _base_control:Control = null
var _resource_previewer = null



#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val, __labelText:String = "NONE", __prop_name:String = "", settings:Dictionary = {}).(__init_val, __labelText, __prop_name, settings):
	
	set_meta("class", "UI_IF_ApplyChanges")
	
	margin_container = PanelContainer.new()
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_container.name = "margin_container"
	
	input_field_container = VBoxContainer.new()
	input_field_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_field_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	if settings.has("label_visibility"):
		label.visible = settings.label_visibility
	
	_base_control = settings._base_control
	_resource_previewer = settings._resource_previewer


func _ready():
	margin_container.add_child(input_field_container)
	value_container.add_child(margin_container)
	
	_init_ui()
	
	if tab_index > 0:
		ThemeAdapter.assign_node_type(margin_container, 'PanelContainer')
	else:
		margin_container.add_stylebox_override('panel', StyleBoxEmpty.new())


func rebuild_object_input_fields(object:Object):
	FunLib.clear_children(input_field_container)
	if is_instance_valid(object):
		
		var property_sections := {}
		
		for input_field in object.create_input_fields(_base_control, _resource_previewer):
			var nesting := (input_field.prop_name as String).split('/')
			if nesting.size() >= 2:
				if !property_sections.has(nesting[0]): 
					var section = UI_FoldableSection_SCN.instance()
					property_sections[nesting[0]] = {'section': section, 'subsections': {}}
					input_field_container.add_child(section)
					section.set_button_text(nesting[0].capitalize())
					section.set_nesting_level(0)
				
				if nesting.size() >= 3:
					if !property_sections[nesting[0]].subsections.has(nesting[1]):
						var subsection = UI_FoldableSection_SCN.instance()
						property_sections[nesting[0]].subsections[nesting[1]] = {'subsection': subsection} 
						property_sections[nesting[0]].section.add_child(subsection)
						subsection.set_button_text(nesting[1].capitalize())
						subsection.set_nesting_level(1)
					
					property_sections[nesting[0]].subsections[nesting[1]].add_prop_node(input_field)
				else:
					property_sections[nesting[0]].section.add_prop_node(input_field)
			else:
				input_field_container.add_child(input_field)




#-------------------------------------------------------------------------------
# Updaing the UI
#-------------------------------------------------------------------------------


func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	if prop_action is PA_PropSet || prop_action is PA_PropEdit:
		_update_ui_to_val(final_val)


func _update_ui_to_val(val):
	if is_instance_valid(val):
		rebuild_object_input_fields(val)
		visibility_forced = -1
		visible = true
	else:
		rebuild_object_input_fields(null)
		visibility_forced = 0
		visible = false
	._update_ui_to_val(val)
