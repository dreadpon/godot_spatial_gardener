@tool
extends UI_InputField
class_name UI_IF_Button


#-------------------------------------------------------------------------------
# Emits a signal when button is pressed
#-------------------------------------------------------------------------------


var button:Button = null


signal pressed




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _init(__init_val,__labelText:String = "NONE",__prop_name:String = "",settings:Dictionary = {}):
	
	set_meta("class", "UI_IF_Button")
	
	button = Button.new()
	button.name = "button"
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.size_flags_vertical = SIZE_SHRINK_CENTER
	button.text = settings.button_text
	button.connect("pressed",Callable(self,"on_button_pressed"))
	ThemeAdapter.assign_node_type(button, 'InspectorButton')


func _ready():
	value_container.add_child(button)
	
	_init_ui()





#-------------------------------------------------------------------------------
# Button presses
#-------------------------------------------------------------------------------


func on_button_pressed():
	emit_signal("pressed")
