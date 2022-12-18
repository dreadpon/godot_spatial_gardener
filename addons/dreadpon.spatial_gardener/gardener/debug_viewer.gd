tool
extends Spatial


#-------------------------------------------------------------------------------
# A previewer for octree structure
#-------------------------------------------------------------------------------


const FunLib = preload("../utility/fun_lib.gd")
const DebugDraw = preload("../utility/debug_draw.gd")
const MMIOctreeManager = preload("../arborist/mmi_octree/mmi_octree_manager.gd")
const MMIOctreeNode = preload("../arborist/mmi_octree/mmi_octree_node.gd")


# How many/which plants we want to preview
enum PlantViewModeFlags {
	VIEW_NONE = 0,
	VIEW_SELECTED_PLANT = 1,
	VIEW_ALL_ACTIVE_PLANTS = 2,
	VIEW_MAX = 3,
	}

# What parts of an octree we want to preview
enum RenderModeFlags {
	DRAW_OCTREE_NODES = 101,
	DRAW_OCTREE_MEMBERS = 102,
	}


var octree_MMIs:Array = []
var active_plant_view_mode:int = PlantViewModeFlags.VIEW_NONE
var active_render_modes:Array = [RenderModeFlags.DRAW_OCTREE_NODES]

var brush_active_plants:Array = []
var prop_edit_selected_plant: int = -1




#-------------------------------------------------------------------------------
# Debug view menu
#-------------------------------------------------------------------------------


# Create and initialize a debug view menu
static func make_debug_view_menu():
	var debug_view_menu := MenuButton.new()
	debug_view_menu.text = "Gardener Debug Viewer"
	debug_view_menu.get_popup().hide_on_checkable_item_selection = false
	debug_view_menu.get_popup().hide_on_item_selection = false
	
	for i in range(0, PlantViewModeFlags.size() - 1):
		debug_view_menu.get_popup().add_radio_check_item(PlantViewModeFlags.keys()[i].capitalize(), PlantViewModeFlags.values()[i])
	
	debug_view_menu.get_popup().add_separator()
	
	for i in range(0, RenderModeFlags.size()):
		debug_view_menu.get_popup().add_check_item(RenderModeFlags.keys()[i].capitalize(), RenderModeFlags.values()[i])
	
	return debug_view_menu


# Callback when flag is checked on a menu
func flag_checked(debug_view_menu:MenuButton, flag:int):
	var flag_group = flag <= PlantViewModeFlags.VIEW_MAX
	if flag_group:
		active_plant_view_mode = flag
	else:
		if active_render_modes.has(flag):
			active_render_modes.erase(flag)
		else:
			active_render_modes.append(flag)
	
	up_to_date_debug_view_menu(debug_view_menu)


# Reset a menu to the current state of this DebugViewer
func up_to_date_debug_view_menu(debug_view_menu:MenuButton):
	for i in range(0, debug_view_menu.get_popup().get_item_count()):
		debug_view_menu.get_popup().set_item_checked(i, false)
	
	update_debug_view_menu_to_flag(debug_view_menu, active_plant_view_mode)
	for render_mode in active_render_modes:
		update_debug_view_menu_to_flag(debug_view_menu, render_mode)


# Tick a flag in a menu
# TODO Decide if this should be simplified and moved to up_to_date_debug_view_menu
# Since flag checks happen in flag_checked anyways
func update_debug_view_menu_to_flag(debug_view_menu:MenuButton, flag:int):
	var flag_group = flag <= PlantViewModeFlags.VIEW_MAX
	for i in range(0, debug_view_menu.get_popup().get_item_count()):
		var item_id = debug_view_menu.get_popup().get_item_id(i)
		var id_group = item_id <= PlantViewModeFlags.VIEW_MAX
		var opposite_state = !debug_view_menu.get_popup().is_item_checked(i)
		
		if item_id == flag:
			if flag_group:
				debug_view_menu.get_popup().set_item_checked(i, true)
			else:
				debug_view_menu.get_popup().set_item_checked(i, opposite_state)
		elif flag_group == id_group && flag_group:
			debug_view_menu.get_popup().set_item_checked(i, false)




#-------------------------------------------------------------------------------
# Brush active plants
#-------------------------------------------------------------------------------


# Keep a local copy of selected for brush plant indexes
func set_brush_active_plant(is_brush_active, plant_index:int):
	if is_brush_active:
		if !brush_active_plants.has(plant_index):
			brush_active_plants.append(plant_index)
	else:
		if brush_active_plants.has(plant_index):
			brush_active_plants.erase(plant_index)
	brush_active_plants.sort()


func reset_brush_active_plants():
	brush_active_plants = []




#-------------------------------------------------------------------------------
# Selected for prop edit plants
#-------------------------------------------------------------------------------


func set_prop_edit_selected_plant(plant_index:int):
	prop_edit_selected_plant = plant_index


func reset_prop_edit_selected_plant():
	prop_edit_selected_plant = -1




#-------------------------------------------------------------------------------
# Debug redraw requests
#-------------------------------------------------------------------------------


func request_debug_redraw(octree_managers:Array):
	debug_redraw(octree_managers)




#-------------------------------------------------------------------------------
# Drawing the structure
#-------------------------------------------------------------------------------


# Redraw every fitting octree
func debug_redraw(octree_managers:Array):
	var used_octree_managers = []
	
	match active_plant_view_mode:
		# Don't draw anything
		PlantViewModeFlags.VIEW_NONE:
			ensure_MMIs(0)
		# Draw only the plant selected for prop edit
		PlantViewModeFlags.VIEW_SELECTED_PLANT:
			if prop_edit_selected_plant >= 0:
				ensure_MMIs(1)
				used_octree_managers.append(octree_managers[prop_edit_selected_plant])
			else:
				ensure_MMIs(0)
		# Draw all brush active plants
		PlantViewModeFlags.VIEW_ALL_ACTIVE_PLANTS:
			ensure_MMIs(brush_active_plants.size())
			for plant_index in brush_active_plants:
				used_octree_managers.append(octree_managers[plant_index])
	
	for i in range(0, used_octree_managers.size()):
		var MMI:MultiMeshInstance = octree_MMIs[i]
		var octree_mamager:MMIOctreeManager = used_octree_managers[i]
		debug_draw_node(octree_mamager.root_octree_node, MMI)


func erase_all():
	ensure_MMIs(0)


# Make sure there is an MMI for every octree we're about to draw
# Passing 0 effectively erases any debug renders
func ensure_MMIs(amount:int):
	if octree_MMIs.size() < amount:
		for i in range(octree_MMIs.size(), amount):
			var MMI = MultiMeshInstance.new()
			add_child(MMI)
			MMI.cast_shadow = false
			MMI.multimesh = MultiMesh.new()
			MMI.multimesh.transform_format = 1
			MMI.multimesh.color_format = MultiMesh.COLOR_8BIT
			MMI.multimesh.mesh = DebugDraw.generate_cube(Vector3.ONE * 0.5, Color.white)
			octree_MMIs.append(MMI)
	elif octree_MMIs.size() > amount:
		while octree_MMIs.size() > amount:
			remove_child(octree_MMIs.pop_back())


# Recursively draw an octree node
func debug_draw_node(octree_node:MMIOctreeNode, MMI:MultiMeshInstance):
	var draw_node := active_render_modes.has(RenderModeFlags.DRAW_OCTREE_NODES)
	var draw_members := active_render_modes.has(RenderModeFlags.DRAW_OCTREE_MEMBERS)
	
	# Reset the instance counts if this node is a root
	if !octree_node.parent:
		MMI.multimesh.instance_count = 0
		MMI.multimesh.visible_instance_count = 0
		set_debug_redraw_instance_count(octree_node, MMI, draw_node, draw_members)
	
	var extents:Vector3
	var render_transform:Transform
	var index:int
	
	if draw_node:
		extents = Vector3(octree_node.extent, octree_node.extent, octree_node.extent) * 0.999 * 2.0
		render_transform = Transform(Basis.IDENTITY.scaled(extents), octree_node.center_pos)
		index = MMI.multimesh.visible_instance_count
		MMI.multimesh.visible_instance_count += 1
		MMI.multimesh.set_instance_transform(index, render_transform)
		MMI.multimesh.set_instance_color(index, octree_node.debug_get_color())
	
	if draw_members && octree_node.is_leaf:
		var member_extent = FunLib.get_setting_safe("dreadpons_spatial_gardener/debug/debug_viewer_octree_member_size", 0.0) * 0.5
		extents = Vector3(member_extent, member_extent, member_extent)
		var basis = Basis.IDENTITY.scaled(extents)
		for placeform in octree_node.get_placeforms():
			render_transform = Transform(basis, placeform[0])
			index = MMI.multimesh.visible_instance_count
			MMI.multimesh.visible_instance_count += 1
			MMI.multimesh.set_instance_transform(index, render_transform)
			MMI.multimesh.set_instance_color(index, Color.white)
	
	for child in octree_node.child_nodes:
		debug_draw_node(child, MMI)


# Recursively set the appropriate instance count for an MMI
func set_debug_redraw_instance_count(octree_node:MMIOctreeNode, MMI:MultiMeshInstance, draw_node:bool, draw_members:bool):
	if draw_node:
		MMI.multimesh.instance_count += 1
	
	if octree_node.is_leaf && draw_members:
		MMI.multimesh.instance_count += octree_node.member_count()
	
	for child in octree_node.child_nodes:
		set_debug_redraw_instance_count(child, MMI, draw_node, draw_members)
