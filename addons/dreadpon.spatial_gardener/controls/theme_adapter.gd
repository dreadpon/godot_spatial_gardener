tool


#-------------------------------------------------------------------------------
# An function library to search through themes, adapt them and assign to controls
#-------------------------------------------------------------------------------


func _init():
	set_meta("class", "ThemeAdapter")


# Create all custom node types for this plugin
static func adapt_theme(theme:Theme):
	var base_color = theme.get_color('base_color', 'Editor')
	var dark_color_1 = theme.get_color('dark_color_1', 'Editor')
	var dark_color_2 = theme.get_color('dark_color_2', 'Editor')
	var dark_color_3 = theme.get_color('dark_color_3', 'Editor')
	var prop_category_color = theme.get_color('prop_category', 'Editor')
	var prop_section_color = theme.get_color('prop_section', 'Editor')
	var prop_subsection_color = theme.get_color('prop_subsection', 'Editor')
	var true_prop_subsection_color = Color('2d3241')
	var property_font_color = theme.get_color('property_color', 'Editor')
	
	var constant_background_margin := theme.get_stylebox("Background", "EditorStyles").content_margin_top
	var stylebox_content := theme.get_stylebox("Content", "EditorStyles")
	var stylebox_background := theme.get_stylebox("Background", "EditorStyles")
	var LineEdit_stylebox_normal := theme.get_stylebox("normal", "LineEdit")
	
	theme.set_constant("margin_top", "NoMargin", 0)
	theme.set_constant("margin_left", "NoMargin", 0)
	theme.set_constant("margin_bottom", "NoMargin", 0)
	theme.set_constant("margin_right", "NoMargin", 0)
	
	theme.set_constant("margin_top", "ExternalMargin", constant_background_margin)
	theme.set_constant("margin_left", "ExternalMargin", constant_background_margin)
	theme.set_constant("margin_bottom", "ExternalMargin", constant_background_margin)
	theme.set_constant("margin_right", "ExternalMargin", constant_background_margin)
	
	var MultiRangeValuePanel_stylebox_panel := StyleBoxFlat.new()
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "MultiRangeValuePanel", MultiRangeValuePanel_stylebox_panel)
	
	var IF_LineEdit_stylebox := theme.get_stylebox('normal', 'LineEdit').duplicate(true)
	IF_LineEdit_stylebox.bg_color = dark_color_2
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "IF_LineEdit", IF_LineEdit_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "MultiRangeValue", IF_LineEdit_stylebox.duplicate(true))
	
	var MultiRangePropLabel_stylebox_panel := LineEdit_stylebox_normal.duplicate(true)
	MultiRangePropLabel_stylebox_panel.bg_color = dark_color_3
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "MultiRangePropLabel", MultiRangePropLabel_stylebox_panel)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "MultiRangeDashLabel", MultiRangePropLabel_stylebox_panel.duplicate(true))
	
	var PlantTitleLineEdit_stylebox := StyleBoxFlat.new()
	PlantTitleLineEdit_stylebox.bg_color = dark_color_3
	PlantTitleLineEdit_stylebox.content_margin_left = 1
	PlantTitleLineEdit_stylebox.content_margin_right = 1
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "PlantTitleLineEdit", PlantTitleLineEdit_stylebox)
	
	var InspectorPanelContainer_stylebox := theme.get_stylebox('panel', 'PanelContainer').duplicate()
	InspectorPanelContainer_stylebox.draw_center = true
	InspectorPanelContainer_stylebox.bg_color = dark_color_1
	InspectorPanelContainer_stylebox.set_border_width_all(1)
	InspectorPanelContainer_stylebox.border_color = dark_color_3
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "InspectorPanelContainer", InspectorPanelContainer_stylebox)
	
	var InspectorWindowDialog_stylebox := theme.get_stylebox('panel', 'WindowDialog').duplicate()
	InspectorWindowDialog_stylebox.draw_center = true
	InspectorWindowDialog_stylebox.bg_color = dark_color_1
	InspectorWindowDialog_stylebox.border_color = dark_color_3
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "InspectorWindowDialog", InspectorWindowDialog_stylebox)
	
	var InspectorInnerPanelContainer_stylebox := theme.get_stylebox('panel', 'PanelContainer').duplicate()
	InspectorInnerPanelContainer_stylebox.draw_center = false
	InspectorInnerPanelContainer_stylebox.set_border_width_all(1)
	InspectorInnerPanelContainer_stylebox.border_color = dark_color_3
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "InspectorInnerPanelContainer", InspectorInnerPanelContainer_stylebox)
	
	var PropertyCategory_stylebox := StyleBoxFlat.new()#theme.get_stylebox('panel', 'PanelContainer').duplicate()
	PropertyCategory_stylebox.draw_center = true
	PropertyCategory_stylebox.bg_color = prop_category_color
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "PropertyCategory", PropertyCategory_stylebox)
	
	var PropertySection_stylebox := theme.get_stylebox('panel', 'PanelContainer').duplicate()
	PropertySection_stylebox.draw_center = true
	PropertySection_stylebox.bg_color = prop_subsection_color
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "PropertySection", PropertySection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "PropertySection", PropertySection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "hover", "PropertySection", PropertySection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "pressed", "PropertySection", PropertySection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "focus", "PropertySection", PropertySection_stylebox)
	
	var PropertySubsection_stylebox := theme.get_stylebox('panel', 'PanelContainer').duplicate()
	PropertySubsection_stylebox.draw_center = true
	PropertySubsection_stylebox.bg_color = true_prop_subsection_color
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "PropertySubsection", PropertySubsection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "PropertySubsection", PropertySubsection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "hover", "PropertySubsection", PropertySubsection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "pressed", "PropertySubsection", PropertySubsection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "focus", "PropertySubsection", PropertySubsection_stylebox)
	
	var InspectorButton_stylebox_normal := theme.get_stylebox('normal', 'Button').duplicate()
	var InspectorButton_stylebox_hover := theme.get_stylebox('hover', 'Button').duplicate()
	var InspectorButton_stylebox_pressed := theme.get_stylebox('pressed', 'Button').duplicate()
	var InspectorButton_stylebox_focus := theme.get_stylebox('focus', 'Button').duplicate()
	InspectorButton_stylebox_normal.bg_color = dark_color_2
	InspectorButton_stylebox_hover.bg_color = dark_color_2
	InspectorButton_stylebox_pressed.bg_color = dark_color_2
	InspectorButton_stylebox_focus.bg_color = dark_color_2
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "InspectorButton", InspectorButton_stylebox_normal)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "hover", "InspectorButton", InspectorButton_stylebox_hover)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "pressed", "InspectorButton", InspectorButton_stylebox_pressed)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "focus", "InspectorButton", InspectorButton_stylebox_focus)


# Iterate through controls and return the first found theme
static func get_theme(node:Node) -> Theme:
	return ThemeOverrider.get_theme(node)


# "Assign" a theme node type
# (Not supported by Godot AFAIK. For now - manually set all overrides from the given node type)
static func assign_node_type(target_control:Control, node_type:String):
	assert(target_control)
	
	if !target_control.is_inside_tree():
		var theme_overrider := ThemeOverrider.new()
		# We reference ThemeOverrider manually since connecting a signal doesn't
		theme_overrider.reference()
		# Our theme overrides can be assigned only after node enters the tree (usually)
		target_control.connect("tree_entered", theme_overrider, "set_overrides", [target_control, node_type])
	else:
		# No reference/dereference here since we don't need to keep this ThemeOverrider
		ThemeOverrider.new().set_overrides(target_control, node_type)


# Get styleboxes associated with nested objects
static func lookup_sub_inspector_styleboxes(search_node:Node, sub_index:int):
	var theme := get_theme(search_node)
	var styleboxes := {}
	
	var sub_inspector_bg = "sub_inspector_bg%d" % [sub_index]
	var sub_inspector_property_bg = "sub_inspector_property_bg%d" % [sub_index]
	var sub_inspector_property_bg_selected = "sub_inspector_property_bg_selected%d" % [sub_index]
	
	var stylebox_names := theme.get_stylebox_list("Editor")
	for stylebox_name in stylebox_names:
		if stylebox_name == sub_inspector_bg:
			styleboxes.sub_inspector_bg = theme.get_stylebox(sub_inspector_bg, "Editor")
		elif stylebox_name == sub_inspector_property_bg:
			styleboxes.sub_inspector_property_bg = theme.get_stylebox(sub_inspector_property_bg, "Editor")
		elif stylebox_name == sub_inspector_property_bg_selected:
			styleboxes.sub_inspector_property_bg_selected = theme.get_stylebox(sub_inspector_property_bg_selected, "Editor")
	return styleboxes




#-------------------------------------------------------------------------------
# A helper object to delay theme node type assignment until Control enters the tree
#-------------------------------------------------------------------------------
class ThemeOverrider extends Reference:
	
	
	func _init():
		set_meta("class", "ThemeOverrider")
	
	
	func set_overrides(target_control:Control, node_type:String):
		var theme := get_theme(target_control)
		
		
		for item_name in theme.get_color_list(node_type):
			var item_value = theme.get_color(item_name, node_type)
			target_control.add_color_override(item_name, item_value)
		
		for item_name in theme.get_constant_list(node_type):
			var item_value = theme.get_constant(item_name, node_type)
			target_control.add_constant_override(item_name, item_value)
		
		for item_name in theme.get_font_list(node_type):
			var item_value = theme.get_font(item_name, node_type)
			target_control.add_font_override(item_name, item_value)
		
		for item_name in theme.get_icon_list(node_type):
			var item_value = theme.get_icon(item_name, node_type)
			target_control.add_icon_override(item_name, item_value)
		
		for item_name in theme.get_stylebox_list(node_type):
			var item_value = theme.get_stylebox(item_name, node_type)
			target_control.add_stylebox_override(item_name, item_value)
		
		# If ThemeOverrider was called from a signal - unreference to free it
		if target_control.is_connected("tree_entered", self, "set_overrides"):
			target_control.disconnect("tree_entered", self, "set_overrides")
			self.unreference()
	
	
	# Iterate through controls and return the first found theme
	static func get_theme(node:Node) -> Theme:
		var theme = null
		while node != null:
			if "theme" in node:
				theme = node.theme
			if theme != null:
				break
			node = node.get_parent()
		return theme
