tool
extends MarginContainer


#-------------------------------------------------------------------------------
# Displays the UI for Greenhouse + its plants and Toolshed + its brushes
#-------------------------------------------------------------------------------


const FunLib = preload("../utility/fun_lib.gd")
const ThemeAdapter = preload("theme_adapter.gd")


var gardener_ui_tools:VSplitContainer = VSplitContainer.new()
var gardener_ui_invalid_setup:Label = Label.new()




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _ready():
	set_meta("class", "UI_SidePanel")
	
	ThemeAdapter.assign_node_type(self, "ExternalMargin")
	
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_stretch_ratio = 0.3
	rect_min_size.x = 275.0
	
	gardener_ui_tools.name = "gardener_ui_tools"
	gardener_ui_tools.split_offset = 80
	gardener_ui_tools.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	gardener_ui_invalid_setup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gardener_ui_invalid_setup.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gardener_ui_invalid_setup.align = Label.ALIGN_CENTER
	gardener_ui_invalid_setup.valign = Label.VALIGN_CENTER
	gardener_ui_invalid_setup.text = "To begin, set the Gardener's Work Directory in the Inspector"
	gardener_ui_invalid_setup.autowrap = true
	
	add_child(gardener_ui_tools)
	add_child(gardener_ui_invalid_setup)
	
	for child_index in range(0, 2):
		var child_container := PanelContainer.new()
		child_container.name = "child_container_%d" % [child_index]
		gardener_ui_tools.add_child(child_container)
		ThemeAdapter.assign_node_type(child_container, "GardenerToolPanel")




#-------------------------------------------------------------------------------
# Updating the UI
#-------------------------------------------------------------------------------


# Set Greenhouse/Toolshed UI as a child
# Can pass an index to specify child order, but only 2 children max are supported (intentionally)
func set_tool_ui(control:Control, index:int):
	if index >= gardener_ui_tools.get_child_count(): return
	
	var child_container:Control = gardener_ui_tools.get_child(index)
	if is_instance_valid(child_container):
		FunLib.clear_children(child_container)
	child_container.add_child(control)


# Switch between invalid setup error and normal tool view
func set_main_control_state(state):
	if state:
		gardener_ui_tools.visible = true
		gardener_ui_invalid_setup.visible = false
	else:
		gardener_ui_tools.visible = false
		gardener_ui_invalid_setup.visible = true
