tool
extends TabContainer


#-------------------------------------------------------------------------------
# Displays the UI for Greenhouse + its plants and Toolshed + its brushes
#-------------------------------------------------------------------------------


const FunLib = preload("../../utility/fun_lib.gd")
const ThemeAdapter = preload("../theme_adapter.gd")
const FoldableSection = preload("ui_foldable_section.gd")

const Greenhouse = preload("../../greenhouse/greenhouse.gd")
const PropAction = preload('../../utility/input_field_resource/prop_action.gd')
const PA_PropSet = preload("../../utility/input_field_resource/pa_prop_set.gd")
const PA_ArrayInsert = preload("../../utility/input_field_resource/pa_array_insert.gd")
const PA_ArrayRemove = preload("../../utility/input_field_resource/pa_array_remove.gd")
const PA_ArraySet = preload("../../utility/input_field_resource/pa_array_set.gd")

onready var panel_container_tools_nd = $PanelContainer_Tools
onready var panel_container_tools_split_nd = $PanelContainer_Tools/PanelContainer_Tools_Split
onready var label_error_nd = $Label_Error




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _ready():
	set_meta("class", "UI_SidePanel")
	
	ThemeAdapter.assign_node_type(panel_container_tools_nd, "InspectorPanelContainer")




#-------------------------------------------------------------------------------
# Updating the UI
#-------------------------------------------------------------------------------


# Set Greenhouse/Toolshed UI as a child
# Can pass an index to specify child order
func set_tool_ui(control:Control, index:int):
	if panel_container_tools_split_nd.get_child_count() > index:
		panel_container_tools_split_nd.remove_child(panel_container_tools_split_nd.get_child(index))
	
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
# TODO if there's a ui/input_field_resource refactor in the future, optimize folding as well

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
	if prop_action is PA_PropSet && prop_action.prop == 'plant_types/selected_for_edit_resource':
		if greenhouse.selected_for_edit_resource:
			var greenhouse_id = get_res_name_or_path(folding_states, greenhouse)
			var plant_id = get_res_name_or_path(folding_states[greenhouse_id], greenhouse.selected_for_edit_resource)
			if folding_states.has(greenhouse_id) && folding_states[greenhouse_id].has(plant_id):
				call_deferred('set_folding_states', folding_states[greenhouse_id][plant_id])
			call_deferred('bind_foldables', self, folding_states, greenhouse_id, plant_id)


# Something caused a folding update (typically a gardener selected for edit)
func refresh_folding_states_for_greenhouse(folding_states:Dictionary, greenhouse:Greenhouse):
	if !greenhouse.selected_for_edit_resource: return
	var greenhouse_id = get_res_name_or_path(folding_states, greenhouse)
	var plant_id = get_res_name_or_path(folding_states[greenhouse_id], greenhouse.selected_for_edit_resource)
	if folding_states.has(greenhouse_id) && folding_states[greenhouse_id].has(plant_id):
		call_deferred('set_folding_states', folding_states[greenhouse_id][plant_id])
	call_deferred('bind_foldables', self, folding_states, greenhouse_id, plant_id)


# Restore folding states
func set_folding_states(states: Dictionary):
	for path in states:
		var abs_path = str(get_path()) + '/' + str(path)
		if has_node(abs_path):
			get_node(abs_path).folded = states[path]


# Bind foldable ui elements to update the relevant folding states
func bind_foldables(node:Node, folding_states: Dictionary, greenhouse_id: String, plant_id: String):
	if node is FoldableSection:
		node.connect('folding_state_changed', self, 'on_foldable_folding_state_changed', [node, folding_states, greenhouse_id, plant_id])
		folding_states[greenhouse_id][plant_id][get_path_to(node)] = node.folded
	for child in node.get_children():
		bind_foldables(child, folding_states, greenhouse_id, plant_id)


# Foldable signal callback. Save it's state to plugin state
func on_foldable_folding_state_changed(folded:bool, node:Node, folding_states: Dictionary, greenhouse_id: String, plant_id: String):
	folding_states[greenhouse_id][plant_id][get_path_to(node)] = folded


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
