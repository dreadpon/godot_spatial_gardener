@tool
extends MarginContainer




@export var arrow_down:ImageTexture = null
@export var arrow_right:ImageTexture = null

var folded: bool = false : set = set_folded
var button_text: String = 'Section' : set = set_button_text
var nesting_level: int = 0 : set = set_nesting_level

signal folding_state_changed(new_state)




func _ready():
	set_folded(folded)
	set_button_text(button_text)
	set_nesting_level(nesting_level)
	
#	if is_instance_of(get_parent(), BoxContainer):
#		var separation = get_parent().get_theme_constant('separation')
#		add_theme_constant_override('offset_bottom', -separation)


func toggle_folded():
	set_folded(!folded)


func set_folded(val):
	folded = val
#	if is_node_ready():
	$VBoxContainer_Main/HBoxContainer_Offset.visible = !folded
	$VBoxContainer_Main/Button_Fold.icon = arrow_right if folded else arrow_down
	folding_state_changed.emit(folded)


func set_button_text(val):
	button_text = val
#	if is_node_ready():
	$VBoxContainer_Main/Button_Fold.text = button_text


func add_prop_node(prop_node: Control):
	$VBoxContainer_Main/HBoxContainer_Offset/VBoxContainer_Properties.add_child(prop_node)


func set_nesting_level(val):
	nesting_level = val
#	if is_node_ready():
	match nesting_level:
		0:
			$VBoxContainer_Main/Button_Fold.theme_type_variation = "PropertySection"
		1:
			$VBoxContainer_Main/Button_Fold.theme_type_variation = "PropertySubsection"
