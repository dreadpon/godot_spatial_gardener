@tool
extends TabContainer


#-------------------------------------------------------------------------------
# Displays the UI for Greenhouse + its plants and Toolshed + its brushes
#-------------------------------------------------------------------------------


const FunLib = preload("../../utility/fun_lib.gd")
const FoldableSection = preload("ui_foldable_section.gd")
const UI_IF_Object = preload("../input_fields/ui_if_object.gd")

const Greenhouse = preload("../../greenhouse/greenhouse.gd")
const PropAction = preload('../../utility/input_field_resource/prop_action.gd')
const PA_PropSet = preload("../../utility/input_field_resource/pa_prop_set.gd")
const PA_ArrayInsert = preload("../../utility/input_field_resource/pa_array_insert.gd")
const PA_ArrayRemove = preload("../../utility/input_field_resource/pa_array_remove.gd")
const PA_ArraySet = preload("../../utility/input_field_resource/pa_array_set.gd")

@onready var panel_container_tools_nd = $PanelContainer
@onready var panel_container_tools_split_nd = $PanelContainer/PanelContainer_Tools_Split
@onready var label_error_nd = $MarginContainer/Label_Error




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _ready():
	set_meta("class", "UI_SidePanel")
	
	panel_container_tools_nd.theme_type_variation = "InspectorPanelContainer"




#-------------------------------------------------------------------------------
# Updating the UI
#-------------------------------------------------------------------------------


# Set Greenhouse/Toolshed UI as a child
# Can pass an index to specify child order
func set_tool_ui(control:Control, index:int):
	if panel_container_tools_split_nd.get_child_count() > index:
		var last_tool = panel_container_tools_split_nd.get_child(index)
		panel_container_tools_split_nd.remove_child(last_tool)
		last_tool.queue_free()
	
	panel_container_tools_split_nd.add_child(control)
	if panel_container_tools_split_nd.get_child_count() > index:
		panel_container_tools_split_nd.move_child(control, index)


# Switch between invalid setup error and normal tool view
func set_main_control_state(state):
	current_tab = 0 if state else 1




#-------------------------------------------------------------------------------
# Folding sections
#-------------------------------------------------------------------------------

# Not a fan of how brute-force it is
# TODO: this WILL NOT WORK with nested foldables or in any slightly-different configuration
#		in the future, we need to associated foldables directly with their input_field_resource
#		and bake that association into foldable states

# Remove states that represent deleted resources
func cleanup_folding_states(folding_states:Dictionary):
	for greenhouse_id in folding_states.keys().duplicate():
		# Remove not found resource paths, but keep resource names until converted to paths
		if !is_res_name(greenhouse_id) && !ResourceLoader.exists(greenhouse_id):
			folding_states.erase(greenhouse_id)
		else:
			for plant_id in folding_states[greenhouse_id].keys().duplicate():
				if !is_res_name(plant_id) && !ResourceLoader.exists(plant_id):
					folding_states[greenhouse_id].erase(plant_id)


# Selected a new plant for edit. Update it's folding and bind foldables
func on_greenhouse_prop_action_executed(folding_states:Dictionary, greenhouse:Greenhouse, prop_action: PropAction, final_val):
	if is_instance_of(prop_action, PA_PropSet) && prop_action.prop == 'plant_types/selected_for_edit_resource':
		refresh_folding_states_for_greenhouse(folding_states, greenhouse)


# Something caused a folding update (typically a gardener selected for edit)
func refresh_folding_states_for_greenhouse(folding_states:Dictionary, greenhouse:Greenhouse):
	if !greenhouse.selected_for_edit_resource: return
	var greenhouse_id = get_res_name_or_path(folding_states, greenhouse)
	var plant_id = get_res_name_or_path(folding_states[greenhouse_id], greenhouse.selected_for_edit_resource)
	if folding_states.has(greenhouse_id) && folding_states[greenhouse_id].has(plant_id):
		call_deferred('set_folding_states', self, folding_states[greenhouse_id][plant_id])
	call_deferred('bind_foldables', self, folding_states, greenhouse_id, plant_id)


# Restore folding states
func set_folding_states(node:Node, states: Dictionary):
	if is_instance_of(node, UI_IF_Object):
		var section_node = null
		for section_name in node.property_sections:
			section_node = node.property_sections[section_name].section
			section_node.folded = states.get(section_name, false)
	for child in node.get_children():
		set_folding_states(child, states)


# Bind foldable ui elements to update the relevant folding states
func bind_foldables(node:Node, folding_states: Dictionary, greenhouse_id: String, plant_id: String):
	if is_instance_of(node, UI_IF_Object):
		var section_node = null
		for section_name in node.property_sections:
			section_node = node.property_sections[section_name].section
			section_node.folding_state_changed.connect(on_foldable_folding_state_changed.bind(section_name, folding_states, greenhouse_id, plant_id))
			on_foldable_folding_state_changed(section_node.folded, section_name, folding_states, greenhouse_id, plant_id)
	for child in node.get_children():
		bind_foldables(child, folding_states, greenhouse_id, plant_id)


# Foldable signal callback. Save it's state to plugin state
func on_foldable_folding_state_changed(folded:bool, section_name:String, folding_states: Dictionary, greenhouse_id: String, plant_id: String):
	folding_states[greenhouse_id][plant_id][section_name] = folded


# Get resource path to use as ID. If resource hasn't been saved yet - use it's 'name' instead
# Also acts as a replacer when folding_states have resource names instead of paths, but paths became available
func get_res_name_or_path(target_dict:Dictionary, res):
	var res_name = str(res)
	if target_dict.has(res_name) && res.resource_path != '':
		target_dict[res.resource_path] = target_dict[res_name]
		target_dict.erase(res_name)
	
	var res_id = str(res) if res.resource_path == '' else res.resource_path
	if !target_dict.has(res_id):
		target_dict[res_id] = {}
	
	return res_id


# Check if giver string represents a resource name (e.g. [Resource:9000])
func is_res_name(string: String):
	var result = string.begins_with('[') && string.ends_with(']')
	return result
