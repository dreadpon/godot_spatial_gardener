tool
extends MarginContainer


const ThemeAdapter = preload("../theme_adapter.gd")

export var arrow_down:Image = null
export var arrow_right:Image = null

var folded: bool = false setget set_folded
var button_text: String = 'Section' setget set_button_text
var pending_children: Array = []
var nesting_level: int = 0 setget set_nesting_level

signal folding_state_changed(new_state)




func _ready():
	add_prop_node(null)
	set_folded(folded)
	set_button_text(button_text)
	set_nesting_level(nesting_level)
	
	if get_parent() is BoxContainer:
		var separation = get_parent().get_constant('separation')
		add_constant_override('margin_bottom', -separation)


func toggle_folded():
	set_folded(!folded)


func set_folded(val):
	folded = val
	if is_inside_tree():
		$VBoxContainer_Main/HBoxContainer_Offset.visible = !folded
		$VBoxContainer_Main/Button_Fold.icon.image = arrow_right if folded else arrow_down
	emit_signal('folding_state_changed', folded)


func set_button_text(val):
	button_text = val
	if is_inside_tree():
		$VBoxContainer_Main/Button_Fold.text = button_text


func add_prop_node(prop_node: Control):
	if prop_node:
		pending_children.append(prop_node)
	if is_inside_tree():
		for child in pending_children:
			$VBoxContainer_Main/HBoxContainer_Offset/VBoxContainer_Properties.add_child(child)
		pending_children = []


func set_nesting_level(val):
	nesting_level = val
	if is_inside_tree():
		match nesting_level:
			0:
				ThemeAdapter.assign_node_type($VBoxContainer_Main/Button_Fold, 'PropertySection')
			1:
				ThemeAdapter.assign_node_type($VBoxContainer_Main/Button_Fold, 'PropertySubsection')
