@tool
extends "ui_input_field.gd"


#-------------------------------------------------------------------------------
# Shows a dialog with InputField controls when button is pressed
# InputField controls will be set with PA_PropSet if dialog was confirmed
# InputField controls will be reverted to initial values if dialog was canceled
#-------------------------------------------------------------------------------


const UI_FoldableSection_SCN = preload('../side_panel/ui_foldable_section.tscn')

var margin_container:PanelContainer = null
var input_field_container:VBoxContainer = null
var _base_control:Control = null
var _resource_previewer = null
var property_sections: Dictionary = {}



#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val, __labelText:String = "NONE", __prop_name:String = "", settings:Dictionary = {}):
	super(__init_val, __labelText, __prop_name, settings)
	set_meta("class", "UI_IF_Object")
	
	margin_container = PanelContainer.new()
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_container.name = "margin_container"
	
	input_field_container = VBoxContainer.new()
	input_field_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_field_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	input_field_container.add_theme_constant_override("separation", 0)
	
	if settings.has("label_visibility"):
		label.visible = settings.label_visibility
	
	margin_container.add_child(input_field_container)
	container_box.add_child(margin_container)


func prepare_input_field(__init_val, __base_control:Control, __resource_previewer):
	super(__init_val, __base_control, __resource_previewer)
	_base_control = __base_control
	_resource_previewer = __resource_previewer


func _ready():
	super()
	if tab_index > 0:
		margin_container.theme_type_variation = "PanelContainer"
	else:
		margin_container.add_theme_stylebox_override('panel', StyleBoxEmpty.new())


func _cleanup():
	super()
	if is_instance_valid(margin_container):
		margin_container.queue_free()
	if is_instance_valid(input_field_container):
		input_field_container.queue_free()


func rebuild_object_input_fields(object:Object):
	if !is_node_ready():
		await ready
	FunLib.free_children(input_field_container)
	if is_instance_valid(object):
		
		property_sections = {}
		var section_dict = {}
		var subsection_dict = {}
		var nest_section_name = ""
		var nest_subsection_name = ""
		
		var input_fields = object.create_input_fields(_base_control, _resource_previewer)
		for input_field in input_fields.values():
			var nesting := (input_field.prop_name as String).split('/')

			if nesting.size() >= 2:
				nest_section_name = nesting[0]
				section_dict = property_sections.get(nest_section_name, null)
				if section_dict == null: 
					var section = UI_FoldableSection_SCN.instantiate()
					input_field_container.add_child(section)
					section.set_button_text(nest_section_name.capitalize())
					section.set_nesting_level(0)
					section_dict = {'section': section, 'subsections': {}}
					property_sections[nest_section_name] = section_dict

				if nesting.size() >= 3:
					nest_subsection_name = nesting[1]
					subsection_dict = section_dict.subsections.get(nest_subsection_name, null)
					if subsection_dict == null: 
						var subsection = UI_FoldableSection_SCN.instantiate()
						section_dict.section.add_child(subsection)
						subsection.set_button_text(nest_subsection_name.capitalize())
						subsection.set_nesting_level(1)
						subsection_dict = {'subsection': subsection} 
						section_dict.subsections[nest_subsection_name] = subsection_dict

					subsection_dict.add_prop_node(input_field)
				else:
					section_dict.section.add_prop_node(input_field)
			else:
				input_field_container.add_child(input_field)
#		print("sections %d end" % [Time.get_ticks_msec()])




#-------------------------------------------------------------------------------
# Updaing the UI
#-------------------------------------------------------------------------------


func _update_ui_to_prop_action(prop_action:PropAction, final_val):
	if is_instance_of(prop_action, PA_PropSet) || is_instance_of(prop_action, PA_PropEdit):
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
	super._update_ui_to_val(val)
