@tool


#-------------------------------------------------------------------------------
# An function library to search through themes, adapt them and assign to controls
#-------------------------------------------------------------------------------


func _init():
	set_meta("class", "ThemeAdapter")


# Create all custom node types for this plugin
static func adapt_theme(theme:Theme, duplicate_theme: bool = true) -> Theme:
	if duplicate_theme:
		theme = theme.duplicate()
	
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
	var PanelContainer_stylebox_panel = theme.get_stylebox('panel', 'PanelContainer')
	var Window_stylebox_panel = theme.get_stylebox('panel', 'Window')
	var Button_stylebox_normal := theme.get_stylebox('normal', 'Button')
	var Button_stylebox_hover := theme.get_stylebox('hover', 'Button')
	var Button_stylebox_pressed := theme.get_stylebox('pressed', 'Button')
	var Button_stylebox_focus := theme.get_stylebox('focus', 'Button')
	
	# NoMargin -> MarginContainer
	theme.set_constant("offset_top", "NoMargin", 0)
	theme.set_constant("offset_left", "NoMargin", 0)
	theme.set_constant("offset_bottom", "NoMargin", 0)
	theme.set_constant("offset_right", "NoMargin", 0)
	theme.set_type_variation("NoMargin", "MarginContainer")

	# ExternalMargin -> MarginContainer
	theme.set_constant("offset_top", "ExternalMargin", constant_background_margin)
	theme.set_constant("offset_left", "ExternalMargin", constant_background_margin)
	theme.set_constant("offset_bottom", "ExternalMargin", constant_background_margin)
	theme.set_constant("offset_right", "ExternalMargin", constant_background_margin)
	theme.set_type_variation("ExternalMargin", "MarginContainer")
	
	# MultiRangeValuePanel -> PanelContainer
	var MultiRangeValuePanel_stylebox_panel := StyleBoxFlat.new()
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "MultiRangeValuePanel", MultiRangeValuePanel_stylebox_panel)
	theme.set_type_variation("MultiRangeValuePanel", "PanelContainer")
	
	# IF_LineEdit -> LineEdit
	var IF_LineEdit_stylebox := LineEdit_stylebox_normal.duplicate(true)
	IF_LineEdit_stylebox.bg_color = dark_color_2
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "IF_LineEdit", IF_LineEdit_stylebox)
	theme.set_type_variation("IF_LineEdit", "LineEdit")

	# MultiRangeValue -> LineEdit
	var MultiRangeValue_stylebox := IF_LineEdit_stylebox.duplicate(true)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "MultiRangeValue", MultiRangeValue_stylebox)
	theme.set_type_variation("MultiRangeValue", "LineEdit")
	
	# MultiRangePropLabel -> Label
	var MultiRangePropLabel_stylebox_panel := LineEdit_stylebox_normal.duplicate(true)
	MultiRangePropLabel_stylebox_panel.bg_color = dark_color_3
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "MultiRangePropLabel", MultiRangePropLabel_stylebox_panel)
	theme.set_type_variation("MultiRangePropLabel", "Label")

	# MultiRangeDashLabel -> Label
	var MultiRangeDashLabel_stylebox_panel := MultiRangePropLabel_stylebox_panel.duplicate(true)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "MultiRangeDashLabel", MultiRangeDashLabel_stylebox_panel)
	theme.set_type_variation("MultiRangeDashLabel", "Label")
	
	# PlantTitleLineEdit -> LineEdit
	var PlantTitleLineEdit_stylebox := StyleBoxFlat.new()
	PlantTitleLineEdit_stylebox.bg_color = dark_color_3
	PlantTitleLineEdit_stylebox.content_margin_left = 1
	PlantTitleLineEdit_stylebox.content_margin_right = 1
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "PlantTitleLineEdit", PlantTitleLineEdit_stylebox)
	theme.set_type_variation("PlantTitleLineEdit", "LineEdit")
	
	# InspectorPanelContainer -> PanelContainer
	var InspectorPanelContainer_stylebox := PanelContainer_stylebox_panel.duplicate(true)
	InspectorPanelContainer_stylebox.draw_center = true
	InspectorPanelContainer_stylebox.bg_color = dark_color_1
	InspectorPanelContainer_stylebox.set_border_width_all(1)
	InspectorPanelContainer_stylebox.border_color = dark_color_3
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "InspectorPanelContainer", InspectorPanelContainer_stylebox)
	theme.set_type_variation("InspectorPanelContainer", "PanelContainer")
	
	# InspectorWindowDialog -> Window
	var InspectorWindowDialog_stylebox := Window_stylebox_panel.duplicate(true)
	InspectorWindowDialog_stylebox.draw_center = true
	InspectorWindowDialog_stylebox.bg_color = dark_color_1
	InspectorWindowDialog_stylebox.border_color = dark_color_3
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "InspectorWindowDialog", InspectorWindowDialog_stylebox)
	theme.set_type_variation("InspectorWindowDialog", "Window")
	
	# InspectorInnerPanelContainer -> PanelContainer
	var InspectorInnerPanelContainer_stylebox := PanelContainer_stylebox_panel.duplicate(true)
	InspectorInnerPanelContainer_stylebox.draw_center = false
	InspectorInnerPanelContainer_stylebox.set_border_width_all(1)
	InspectorInnerPanelContainer_stylebox.border_color = dark_color_3
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "InspectorInnerPanelContainer", InspectorInnerPanelContainer_stylebox)
	theme.set_type_variation("InspectorInnerPanelContainer", "PanelContainer")
	
	# PropertyCategory -> PanelContainer
	var PropertyCategory_stylebox := StyleBoxFlat.new()
	PropertyCategory_stylebox.draw_center = true
	PropertyCategory_stylebox.bg_color = prop_category_color
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "PropertyCategory", PropertyCategory_stylebox)
	theme.set_type_variation("PropertyCategory", "PanelContainer")
	
	# PropertySection -> PanelContainer
	var PropertySection_stylebox := PanelContainer_stylebox_panel.duplicate(true)
	PropertySection_stylebox.draw_center = true
	PropertySection_stylebox.bg_color = prop_subsection_color
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "PropertySection", PropertySection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "PropertySection", PropertySection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "hover", "PropertySection", PropertySection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "pressed", "PropertySection", PropertySection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "focus", "PropertySection", PropertySection_stylebox)
	theme.set_type_variation("PropertySection", "PanelContainer")
	
	# PropertySubsection -> PanelContainer
	var PropertySubsection_stylebox := PanelContainer_stylebox_panel.duplicate(true)
	PropertySubsection_stylebox.draw_center = true
	PropertySubsection_stylebox.bg_color = true_prop_subsection_color
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "PropertySubsection", PropertySubsection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "PropertySubsection", PropertySubsection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "hover", "PropertySubsection", PropertySubsection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "pressed", "PropertySubsection", PropertySubsection_stylebox)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "focus", "PropertySubsection", PropertySubsection_stylebox)
	theme.set_type_variation("PropertySubsection", "PanelContainer")
	
	# Buttons
	var InspectorButton_stylebox_normal := Button_stylebox_normal.duplicate(true)
	var InspectorButton_stylebox_hover := Button_stylebox_hover.duplicate(true)
	var InspectorButton_stylebox_pressed := Button_stylebox_pressed.duplicate(true)
	var InspectorButton_stylebox_focus := Button_stylebox_focus.duplicate(true)
	InspectorButton_stylebox_normal.bg_color = dark_color_2
	InspectorButton_stylebox_hover.bg_color = dark_color_2 * 1.2
	InspectorButton_stylebox_pressed.bg_color = dark_color_2
	InspectorButton_stylebox_focus.bg_color = dark_color_2
	
	# ActionThumbnail_SelectionPanel -> Panel
	var ActionThumbnail_SelectionPanel_stylebox := Button_stylebox_focus.duplicate(true)
	ActionThumbnail_SelectionPanel_stylebox.bg_color = Color8(255, 255, 255, 51)
	ActionThumbnail_SelectionPanel_stylebox.border_color = Color8(255, 255, 255, 255)
	ActionThumbnail_SelectionPanel_stylebox.draw_center = true
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "ActionThumbnail_SelectionPanel", ActionThumbnail_SelectionPanel_stylebox)
	theme.set_type_variation("ActionThumbnail_SelectionPanel", "PanelContainer")

	# InspectorButton -> Button
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "InspectorButton", InspectorButton_stylebox_normal)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "hover", "InspectorButton", InspectorButton_stylebox_hover)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "pressed", "InspectorButton", InspectorButton_stylebox_pressed)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "focus", "InspectorButton", InspectorButton_stylebox_focus)
	theme.set_type_variation("InspectorButton", "Button")

	# InspectorCheckBox -> CheckBox
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "InspectorCheckBox", InspectorButton_stylebox_normal)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "hover", "InspectorCheckBox", InspectorButton_stylebox_hover)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "pressed", "InspectorCheckBox", InspectorButton_stylebox_pressed)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "focus", "InspectorCheckBox", InspectorButton_stylebox_focus)
	theme.set_type_variation("InspectorCheckBox", "CheckBox")

	# InspectorOptionButton -> OptionButton
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "InspectorOptionButton", InspectorButton_stylebox_normal)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "hover", "InspectorOptionButton", InspectorButton_stylebox_hover)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "pressed", "InspectorOptionButton", InspectorButton_stylebox_pressed)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "focus", "InspectorOptionButton", InspectorButton_stylebox_focus)
	theme.set_type_variation("InspectorOptionButton", "OptionButton")
	
	# InspectorMenuButton -> MenuButton
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "InspectorMenuButton", InspectorButton_stylebox_normal)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "hover", "InspectorMenuButton", InspectorButton_stylebox_hover)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "pressed", "InspectorMenuButton", InspectorButton_stylebox_pressed)
	theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "focus", "InspectorMenuButton", InspectorButton_stylebox_focus)
	theme.set_type_variation("InspectorMenuButton", "MenuButton")
	
	return theme


# Iterate through controls and return the first found theme
static func get_theme(node:Node) -> Theme:
	return ThemeOverrider.get_theme(node)


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
class ThemeOverrider extends RefCounted:
	
	
	func _init():
		set_meta("class", "ThemeOverrider")
	
	
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
