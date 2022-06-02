tool


#-------------------------------------------------------------------------------
# An function library to search through themes, adapt them and assign to controls
#-------------------------------------------------------------------------------


func _init():
	set_meta("class", "ThemeAdapter")


# Create all custom node types for this plugin
static func adapt_theme(theme:Theme):
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
	
	var GardenerToolPanel_stylebox_panel := StyleBoxFlat.new()
	GardenerToolPanel_stylebox_panel.bg_color = stylebox_background.bg_color
	GardenerToolPanel_stylebox_panel.content_margin_top = constant_background_margin
	GardenerToolPanel_stylebox_panel.content_margin_left = constant_background_margin
	GardenerToolPanel_stylebox_panel.content_margin_right = constant_background_margin
	GardenerToolPanel_stylebox_panel.content_margin_bottom = constant_background_margin
	GardenerToolPanel_stylebox_panel.set_border_width_all(stylebox_content.border_width_top)
	GardenerToolPanel_stylebox_panel.border_color = stylebox_content.border_color
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "GardenerToolPanel", GardenerToolPanel_stylebox_panel)
	
	var GreenhousePanel_stylebox_panel := StyleBoxFlat.new()
	GreenhousePanel_stylebox_panel.bg_color = stylebox_content.bg_color
	GreenhousePanel_stylebox_panel.set_border_width_all(stylebox_content.border_width_top)
	GreenhousePanel_stylebox_panel.border_color = stylebox_content.border_color
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "GreenhousePanel", GreenhousePanel_stylebox_panel)
	
	var GreenhouseTabContainerTop_stylebox_panel := StyleBoxFlat.new()
	GreenhouseTabContainerTop_stylebox_panel.bg_color = stylebox_content.bg_color
	GreenhouseTabContainerTop_stylebox_panel.set_border_width_all(0)
	GreenhouseTabContainerTop_stylebox_panel.border_width_bottom = stylebox_content.border_width_bottom
	GreenhouseTabContainerTop_stylebox_panel.border_color = stylebox_content.border_color
	GreenhouseTabContainerTop_stylebox_panel.content_margin_top = 10
	GreenhouseTabContainerTop_stylebox_panel.content_margin_bottom = 10
	GreenhouseTabContainerTop_stylebox_panel.content_margin_left = 10
	GreenhouseTabContainerTop_stylebox_panel.content_margin_right = 10
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "GreenhouseTabContainerTop", GreenhouseTabContainerTop_stylebox_panel)
	
	var GreenhouseTabContainerBottom_stylebox_panel = GreenhouseTabContainerTop_stylebox_panel.duplicate(true)
	GreenhouseTabContainerBottom_stylebox_panel.border_width_bottom = 0
	GreenhouseTabContainerBottom_stylebox_panel.border_width_top = stylebox_content.border_width_top
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "GreenhouseTabContainerBottom", GreenhouseTabContainerBottom_stylebox_panel)
	
	var MultiRangeValuePanel_stylebox_panel := StyleBoxFlat.new()
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "MultiRangeValuePanel", MultiRangeValuePanel_stylebox_panel)
	
	var MultiRangePropLabel_stylebox_panel := LineEdit_stylebox_normal.duplicate(true)
	MultiRangePropLabel_stylebox_panel.bg_color = stylebox_background.bg_color
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "MultiRangePropLabel", MultiRangePropLabel_stylebox_panel)
	
	var MultiRangeDashLabel_stylebox_panel := MultiRangePropLabel_stylebox_panel.duplicate(true)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "MultiRangeDashLabel", MultiRangeDashLabel_stylebox_panel)
	
	var MultiRangeValue_stylebox_panel := LineEdit_stylebox_normal.duplicate(true)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "MultiRangeValue", MultiRangeValue_stylebox_panel)


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
