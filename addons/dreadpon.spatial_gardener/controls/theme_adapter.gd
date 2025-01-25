@tool


#-------------------------------------------------------------------------------
# An function library to search through themes, adapt them and assign to controls
#-------------------------------------------------------------------------------


static var editor_theme: Theme = null




func _init():
	set_meta("class", "ThemeAdapter")


# Create all custom node types for this plugin
static func adapt_theme(theme:Theme) -> Theme:
	editor_theme = Theme.new()
	editor_theme.merge_with(theme)
	
	var base_color = editor_theme.get_color('base_color', 'Editor')
	var dark_color_1 = editor_theme.get_color('dark_color_1', 'Editor')
	var dark_color_2 = editor_theme.get_color('dark_color_2', 'Editor')
	var dark_color_3 = editor_theme.get_color('dark_color_3', 'Editor')
	var property_font_color = editor_theme.get_color('property_color', 'Editor')
	
	var constant_background_margin := editor_theme.get_stylebox("Background", "EditorStyles").content_margin_top
	var stylebox_content := editor_theme.get_stylebox("Content", "EditorStyles")
	var stylebox_background := editor_theme.get_stylebox("Background", "EditorStyles")
	var LineEdit_stylebox_normal := editor_theme.get_stylebox("normal", "LineEdit")
	var PanelContainer_stylebox_panel = editor_theme.get_stylebox('panel', 'PanelContainer')
	var Panel_stylebox_panel = editor_theme.get_stylebox('panel', 'Panel')
	var Window_stylebox_panel = editor_theme.get_stylebox('panel', 'Window')
	var Button_stylebox_focus := editor_theme.get_stylebox('focus', 'Button')
	var EditorInspectorCategory_stylebox_bg := editor_theme.get_stylebox('bg', 'EditorInspectorCategory')
	
	var EditorFonts_bold = editor_theme.get_font('bold', 'EditorFonts')
	var EditorFonts_bold_size = editor_theme.get_font_size('bold_size', 'EditorFonts')
	var Tree_font_color = editor_theme.get_color('font_color', 'Tree')
	var Tree_v_separation = editor_theme.get_constant('v_separation', 'Tree')
	var Tree_panel = editor_theme.get_stylebox('panel', 'Tree')
	var Editor_font_color = editor_theme.get_color('font_color', 'Editor')
	var Editor_accent_color = editor_theme.get_color('accent_color', 'Editor')
	var Editor_dark_color_1 = editor_theme.get_color("dark_color_1", 'Editor')
	
	# NoMargin -> MarginContainer
	editor_theme.set_constant("offset_top", "NoMargin", 0)
	editor_theme.set_constant("offset_left", "NoMargin", 0)
	editor_theme.set_constant("offset_bottom", "NoMargin", 0)
	editor_theme.set_constant("offset_right", "NoMargin", 0)
	editor_theme.set_type_variation("NoMargin", "MarginContainer")

	# ExternalMargin -> MarginContainer
	editor_theme.set_constant("offset_top", "ExternalMargin", constant_background_margin)
	editor_theme.set_constant("offset_left", "ExternalMargin", constant_background_margin)
	editor_theme.set_constant("offset_bottom", "ExternalMargin", constant_background_margin)
	editor_theme.set_constant("offset_right", "ExternalMargin", constant_background_margin)
	editor_theme.set_type_variation("ExternalMargin", "MarginContainer")
	
	# IF_LineEdit -> LineEdit
	var IF_LineEdit_stylebox := LineEdit_stylebox_normal.duplicate(true)
	IF_LineEdit_stylebox.bg_color = dark_color_2
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "IF_LineEdit", IF_LineEdit_stylebox)
	editor_theme.set_type_variation("IF_LineEdit", "LineEdit")
	
	# MultiRangeValuePanel -> PanelContainer
	var MultiRangeValuePanel_stylebox_panel := PanelContainer_stylebox_panel.duplicate(true)
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "MultiRangeValuePanel", MultiRangeValuePanel_stylebox_panel)
	editor_theme.set_type_variation("MultiRangeValuePanel", "PanelContainer")
	
	# MultiRangeValue -> LineEdit
	var MultiRangeValue_stylebox := IF_LineEdit_stylebox.duplicate(true)
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "MultiRangeValue", MultiRangeValue_stylebox)
	editor_theme.set_type_variation("MultiRangeValue", "LineEdit")
	
	# MultiRangePropLabel -> Label
	var MultiRangePropLabel_stylebox_panel := PanelContainer_stylebox_panel.duplicate(true)
#	var MultiRangePropLabel_stylebox_panel := LineEdit_stylebox_normal.duplicate(true)
	MultiRangePropLabel_stylebox_panel.bg_color = dark_color_3
	MultiRangePropLabel_stylebox_panel.draw_center = true
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "MultiRangePropLabel", MultiRangePropLabel_stylebox_panel)
	editor_theme.set_type_variation("MultiRangePropLabel", "Label")

	# MultiRangeDashLabel -> Label
	var MultiRangeDashLabel_stylebox_panel := MultiRangePropLabel_stylebox_panel.duplicate(true)
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "MultiRangeDashLabel", MultiRangeDashLabel_stylebox_panel)
	editor_theme.set_type_variation("MultiRangeDashLabel", "Label")
	
	# PlantTitleLineEdit -> LineEdit
	var PlantTitleLineEdit_stylebox := StyleBoxFlat.new()
	PlantTitleLineEdit_stylebox.bg_color = dark_color_3
	PlantTitleLineEdit_stylebox.content_margin_left = 1
	PlantTitleLineEdit_stylebox.content_margin_right = 1
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "PlantTitleLineEdit", PlantTitleLineEdit_stylebox)
	editor_theme.set_type_variation("PlantTitleLineEdit", "LineEdit")
	
	# InspectorPanelContainer -> PanelContainer
	var InspectorPanelContainer_stylebox := Tree_panel.duplicate(true)
	InspectorPanelContainer_stylebox.draw_center = true
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "InspectorPanelContainer", InspectorPanelContainer_stylebox)
	editor_theme.set_type_variation("InspectorPanelContainer", "PanelContainer")
	
	# InspectorWindowDialog -> Window
	var InspectorWindowDialog_stylebox := Window_stylebox_panel.duplicate(true)
	InspectorWindowDialog_stylebox.draw_center = true
	InspectorWindowDialog_stylebox.bg_color = dark_color_1
	InspectorWindowDialog_stylebox.border_color = dark_color_3
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "InspectorWindowDialog", InspectorWindowDialog_stylebox)
	editor_theme.set_type_variation("InspectorWindowDialog", "Window")
	
	# InspectorInnerPanelContainer -> PanelContainer
	var InspectorInnerPanelContainer_stylebox := PanelContainer_stylebox_panel.duplicate(true)
	InspectorInnerPanelContainer_stylebox.draw_center = false
	InspectorInnerPanelContainer_stylebox.set_border_width_all(1)
	InspectorInnerPanelContainer_stylebox.border_color = dark_color_3
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "InspectorInnerPanelContainer", InspectorInnerPanelContainer_stylebox)
	editor_theme.set_theme_item(Theme.DATA_TYPE_FONT, "panel", "InspectorInnerPanelContainer", InspectorInnerPanelContainer_stylebox)
	editor_theme.set_type_variation("InspectorInnerPanelContainer", "PanelContainer")
	
	# PropertyCategory -> Label
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "PropertyCategory", EditorInspectorCategory_stylebox_bg)
	editor_theme.set_theme_item(Theme.DATA_TYPE_FONT, "font", "PropertyCategory", EditorFonts_bold)
	editor_theme.set_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "PropertyCategory", EditorFonts_bold_size)
	editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "PropertyCategory", Tree_font_color)
	editor_theme.set_type_variation("PropertyCategory", "PanelContainer")
	
	# PropertySection -> Button
	var PropertySection_stylebox_bg_color = EditorInspectorCategory_stylebox_bg.bg_color
	PropertySection_stylebox_bg_color.a *= 0.4
	var PropertySection_stylebox_normal := StyleBoxFlat.new()
	PropertySection_stylebox_normal.bg_color = PropertySection_stylebox_bg_color
	PropertySection_stylebox_normal.set_content_margin_all(Tree_v_separation * 0.5)
	var PropertySection_stylebox_hover := PropertySection_stylebox_normal.duplicate(true)
	PropertySection_stylebox_hover.bg_color =PropertySection_stylebox_bg_color.lightened(0.2)
	var PropertySection_stylebox_pressed := PropertySection_stylebox_normal.duplicate(true)
	PropertySection_stylebox_pressed.bg_color = PropertySection_stylebox_bg_color.lightened(-0.05)
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "PropertySection", PropertySection_stylebox_normal)
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "hover", "PropertySection", PropertySection_stylebox_hover)
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "pressed", "PropertySection", PropertySection_stylebox_pressed)
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "focus", "PropertySection", StyleBoxEmpty.new())
	editor_theme.set_theme_item(Theme.DATA_TYPE_FONT, "font", "PropertySection", EditorFonts_bold)
	editor_theme.set_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "PropertySection", EditorFonts_bold_size)
	editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "PropertySection", Editor_font_color)
	editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "font_pressed_color", "PropertySection", Editor_font_color)
	editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "icon_color", "PropertySection", Editor_font_color)
	editor_theme.set_theme_item(Theme.DATA_TYPE_COLOR, "icon_pressed_color", "PropertySection", Editor_font_color)
	editor_theme.set_type_variation("PropertySection", "Button")
	
	# PropertySubsection -> PanelContainer
	var PropertySubsection_stylebox := PanelContainer_stylebox_panel.duplicate(true)
	PropertySubsection_stylebox.draw_center = true
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "PropertySubsection", PropertySubsection_stylebox)
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "normal", "PropertySubsection", PropertySubsection_stylebox)
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "hover", "PropertySubsection", PropertySubsection_stylebox)
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "pressed", "PropertySubsection", PropertySubsection_stylebox)
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "focus", "PropertySubsection", PropertySubsection_stylebox)
	editor_theme.set_type_variation("PropertySubsection", "PanelContainer")
	
	# ActionThumbnail_SelectionPanel -> Panel
	var ActionThumbnail_SelectionPanel_stylebox := Button_stylebox_focus.duplicate(true)
	ActionThumbnail_SelectionPanel_stylebox.bg_color = Color8(255, 255, 255, 51)
	ActionThumbnail_SelectionPanel_stylebox.border_color = Color8(255, 255, 255, 255)
	ActionThumbnail_SelectionPanel_stylebox.draw_center = true
	editor_theme.set_theme_item(Theme.DATA_TYPE_STYLEBOX, "panel", "ActionThumbnail_SelectionPanel", ActionThumbnail_SelectionPanel_stylebox)
	editor_theme.set_type_variation("ActionThumbnail_SelectionPanel", "PanelContainer")

	# InspectorButton -> Button
	# InspectorCheckBox -> CheckBox
	# InspectorOptionButton -> OptionButton
	# InspectorMenuButton -> MenuButton
	for theme_type in ["Button", "CheckBox", "OptionButton", "MenuButton"]:
		for data_type in range(0, editor_theme.DATA_TYPE_MAX):
			for theme_item in editor_theme.get_theme_item_list(data_type, theme_type):
				var item = editor_theme.get_theme_item(data_type, theme_item, theme_type)
				if is_instance_of(item, Resource):
					item = item.duplicate(true)
				if data_type == editor_theme.DATA_TYPE_STYLEBOX:
					match theme_item:
						"normal", "pressed", "focus":
							item.bg_color = dark_color_2
							item.draw_center = true
						"hover":
							item.bg_color = dark_color_2 * 1.2
							item.draw_center = true
						"disabled":
							item.bg_color = dark_color_2 * 1.5
							item.draw_center = true
				editor_theme.set_theme_item(data_type, theme_item, "Inspector" + theme_type, item)
		editor_theme.set_type_variation("Inspector" + theme_type, theme_type)
	
	return editor_theme


# Get styleboxes associated with nested objects
static func lookup_sub_inspector_styleboxes(search_node:Node, sub_index:int):
	var styleboxes := {}
	
	var sub_inspector_bg = "sub_inspector_bg%d" % [sub_index]
	var sub_inspector_property_bg = "sub_inspector_property_bg%d" % [sub_index]
	var sub_inspector_property_bg_selected = "sub_inspector_property_bg_selected%d" % [sub_index]
	
	var stylebox_names := editor_theme.get_stylebox_list("EditorStyles")
	for stylebox_name in stylebox_names:
		if stylebox_name == sub_inspector_bg:
			styleboxes.sub_inspector_bg = editor_theme.get_stylebox(sub_inspector_bg, "EditorStyles")
		elif stylebox_name == sub_inspector_property_bg:
			styleboxes.sub_inspector_property_bg = editor_theme.get_stylebox(sub_inspector_property_bg, "EditorStyles")
		elif stylebox_name == sub_inspector_property_bg_selected:
			styleboxes.sub_inspector_property_bg_selected = editor_theme.get_stylebox(sub_inspector_property_bg_selected, "EditorStyles")
	return styleboxes
	
