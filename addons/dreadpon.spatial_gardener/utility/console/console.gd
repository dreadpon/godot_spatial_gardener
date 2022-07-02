extends Control


const Gardener = preload("../../gardener/gardener.gd")

onready var input_field:TextEdit = $VBoxContainer/InputField
onready var output_field:RichTextLabel = $VBoxContainer/OutputField

export(Array, NodePath) var block_input_PTH:Array = []
var block_input:Array = []

var last_mouse_mode:int




func _ready():
	for node_pth in block_input_PTH:
		if has_node(node_pth):
			block_input.append(get_node(node_pth))
	
	if visible:
		input_field.grab_focus()



func _unhandled_input(event):
	if event is InputEventKey && event.scancode == KEY_QUOTELEFT && !event.pressed:
		toggle_console()
	
	if !visible: return
	
	if event is InputEventKey:
		get_tree().set_input_as_handled()
		
		if !event.pressed:
			match event.scancode:
				KEY_ENTER:
					input_field.text = input_field.text.trim_suffix("\n")
					try_execute_command()
				KEY_ESCAPE:
					toggle_console()


func toggle_console():
	if !visible:
		visible = true
		last_mouse_mode = Input.get_mouse_mode()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		input_field.grab_focus()
	else:
		visible = false
		clear_command()
		Input.set_mouse_mode(last_mouse_mode)
	set_nodes_input_state(!visible)


func set_nodes_input_state(state:bool):
	for node in block_input:
		node.set_process_input(state)


func try_execute_command():
	if input_field.text.empty(): return
	var result = parse_and_execute(input_field.text)
	clear_command()
	print_output(result)


func clear_command():
	input_field.text = ""


func print_output(string:String):
	output_field.append_bbcode(string + "\n\n")


func parse_and_execute(string:String):
	var args:PoolStringArray = string.split(" ")
	
	match args[0]:
		"dump_octrees":
			return dump_octrees(args)
		"dump_scene_tree":
			return debug_scene_tree()
		"clear":
			output_field.bbcode_text = ""
			return ""
		_:
			return "[color=red]Undefined command[/color]"




func dump_octrees(args:Array = []):
	var current_scene := get_tree().get_current_scene()
	var gardener_path := ""
	var octree_index := -1
	
	if args.size() > 1:
		if current_scene.has_node(args[1]) && current_scene.get_node(args[1]) is Gardener:
			gardener_path = args[1]
		else:
			return "[color=red]'%s' wrong node path in argument '%d'[/color]" % [args[0], 1]
	
	if args.size() > 2:
		if args[2].is_valid_integer():
			octree_index = args[2].to_int()
		else:
			return "[color=red]'%s' wrong type in argument '%d'[/color]" % [args[0], 2]
	
	if gardener_path.empty():
		return dump_octrees_from_node(current_scene)
	elif octree_index < 0:
		return dump_octrees_from_gardener(current_scene.get_node(args[1]))
	else:
		return dump_octrees_at_index(current_scene.get_node(args[1]), octree_index)


func dump_octrees_from_node(node:Node):
	var output := ""
	
	if node is Gardener:
		output += dump_octrees_from_gardener(node)
	else:
		for child in node.get_children():
			output += dump_octrees_from_node(child)
	
	return output


func dump_octrees_from_gardener(gardener:Gardener):
	var output := ""
	
	for i in range(0, gardener.get_node("Arborist").octree_managers.size()):
		output += dump_octrees_at_index(gardener, i)
	
	return output


func dump_octrees_at_index(gardener:Gardener, index:int):
	var output := ""
	
	var octree_manager = gardener.get_node("Arborist").octree_managers[index]
	output += octree_manager.root_octree_node.debug_dump_tree() + "\n"
	
	return output




func debug_scene_tree():
	var current_scene := get_tree().get_current_scene()
	return dump_node_descendants(current_scene)


func dump_node_descendants(node:Node, intendation:int = 0):
	var output := ""
	
	var intend_str = ""
	for i in range(0, intendation):
		intend_str += "	"
	var string = "%s%s" % [intend_str, str(node)]
	
	output += string + "\n"
	
	intendation += 1
	for child in node.get_children():
		output += dump_node_descendants(child, intendation)
	
	return output
