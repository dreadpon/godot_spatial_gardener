@tool
extends Control

# NOTE: this is a direct port from Godot's source code
#		I will not pretend to have understood all its ins and outs and will just leave it as it is

const EditorInterfaceInterface = preload("../../utility/editor_interface_interface.gd")

const INT32_MAX = 2147483647

var flag_rects: Array[Rect2] = []
var expand_rect: Rect2
var expand_hovered: bool = false
var expanded: bool = false
var expansion_rows: int = 0
var hovered_index: int = INT32_MAX # nothing is hovered
var read_only: bool = false
var renamed_layer_index: int = -1
var layer_rename: PopupMenu = null
var rename_dialog: ConfirmationDialog = null
var rename_dialog_text: LineEdit = null

var value: int = 0
var layer_group_size: int = 0
var layer_count: int = 0
var names: Array[String] = []
var tooltips: Array[String] = []

signal flag_changed(flag: int)
signal rename_confirmed(layer_id: int, new_name: String)




func _init() -> void:
	rename_dialog = ConfirmationDialog.new()
	var rename_dialog_vb = VBoxContainer.new()
	rename_dialog.add_child(rename_dialog_vb)
	rename_dialog_text = LineEdit.new()
	_vboxcontainer_add_margin_child(rename_dialog_vb, "Name:", rename_dialog_text, false)
	rename_dialog.set_ok_button_text("Rename")
	add_child(rename_dialog)
	rename_dialog.register_text_enter(rename_dialog_text)
	rename_dialog.confirmed.connect(_rename_operation_confirm)
	layer_rename = PopupMenu.new()
	layer_rename.add_item("Rename layer", 0)
	add_child(layer_rename)
	layer_rename.id_pressed.connect(_rename_pressed)


func _vboxcontainer_add_margin_child(p_vboxcontainer: VBoxContainer, p_label: String, p_control: Control, p_expand: bool) -> MarginContainer:
	var l = Label.new()
	l.set_theme_type_variation("HeaderSmall")
	l.set_text(p_label)
	p_vboxcontainer.add_child(l)
	var mc = MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 0)
	mc.add_child(p_control, true)
	p_vboxcontainer.add_child(mc)
	if p_expand:
		mc.set_v_size_flags(SIZE_EXPAND_FILL)

	return mc;



func _rename_pressed(p_menu: int) -> void:
	if renamed_layer_index == INT32_MAX: return

	var name := names[renamed_layer_index]
	rename_dialog.set_title("Renaming layer %d:" % [renamed_layer_index + 1])
	rename_dialog_text.set_text(name)
	rename_dialog_text.select(0, name.length())
	rename_dialog.popup_centered(Vector2(300, 80) * EditorInterfaceInterface.get_ui_scale())
	rename_dialog_text.grab_focus()

	
func _rename_operation_confirm() -> void:
	var new_name := rename_dialog_text.get_text().strip_edges()
	if new_name.length() == 0:
		#EditorNode::get_singleton()->show_warning(TTR("No name provided."));
		return
	elif new_name.contains("/") || new_name.contains("\\") || new_name.contains(":"):
		#EditorNode::get_singleton()->show_warning(TTR("Name contains invalid characters."));
		return
	names[renamed_layer_index] = new_name
	tooltips[renamed_layer_index] = new_name + "\n" + "Bit %d, value %d" %[renamed_layer_index, 1 << renamed_layer_index]
	rename_confirmed.emit(renamed_layer_index, new_name)
	
	
func _update_hovered(p_position: Vector2) -> void:
	var expand_was_hovered := expand_hovered
	expand_hovered = expand_rect.has_point(p_position)
	if expand_hovered != expand_was_hovered:
		queue_redraw()

	if !expand_hovered:
		for i in range(0, flag_rects.size()):
			if flag_rects[i].has_point(p_position):
				# Used to highlight the hovered flag in the layers grid.
				hovered_index = i
				queue_redraw()
				return

	# Remove highlight when no square is hovered.
	if hovered_index != INT32_MAX:
		hovered_index = INT32_MAX
		queue_redraw()
	
	
func _on_hover_exit() -> void:
	if expand_hovered:
		expand_hovered = false
		queue_redraw()
	if hovered_index != INT32_MAX:
		hovered_index = INT32_MAX
		queue_redraw()
	
	
func _update_flag(p_replace: bool) -> void:
	if hovered_index != INT32_MAX:
		# Toggle the flag.
		# We base our choice on the hovered flag, so that it always matches the hovered flag.
		if p_replace:
			# Replace all flags with the hovered flag ("solo mode"),
			# instead of toggling the hovered flags while preserving other flags' state.
			if value == 1 << hovered_index:
				# If the flag is already enabled, enable all other items and disable the current flag.
				# This allows for quicker toggling.
				value = INT32_MAX - (1 << hovered_index)
			else:
				value = 1 << hovered_index
		else:
			if value & (1 << hovered_index):
				value &= ~(1 << hovered_index)
			else:
				value |= (1 << hovered_index)

		flag_changed.emit(value)
		queue_redraw()
	elif expand_hovered:
		expanded = !expanded
		#refresh_minimum_size() # TODO: doesnt work for some reason, figure out to avoid exess refreshes
		queue_redraw()
	
	
func get_grid_size() -> Vector2:
	var font := get_theme_font("font", "Label")
	var font_size := get_theme_font_size("font_size", "Label")
	return Vector2(0, font.get_height(font_size) * 3)


func _notification(p_what: int) -> void:
	match p_what:
		NOTIFICATION_DRAW:
			refresh_minimum_size.call_deferred()
			
			var grid_size := get_grid_size()
			grid_size.x = get_size().x

			flag_rects.clear()

			var prev_expansion_rows := expansion_rows
			expansion_rows = 0

			var bsize := (grid_size.y * 80 / 100) / 2
			var h := bsize * 2 + 1

			var color := get_theme_color("highlight_disabled_color" if read_only else "highlight_color", "Editor")

			var text_color := get_theme_color("font_disabled_color" if read_only else "font_color", "Editor")
			text_color.a *= 0.5

			var text_color_on := get_theme_color("font_disabled_color" if read_only else "font_hover_color", "Editor")
			text_color_on.a *= 0.7

			var vofs := (grid_size.y - h) / 2

			var layer_index := 0

			var arrow_pos: Vector2

			var block_ofs := Vector2(4, vofs)

			while true:
				var ofs := block_ofs

				for i in range(0, 2):
					for k in range(0, layer_group_size):
						var on := value & (1 << layer_index)
						var rect2 := Rect2(ofs, Vector2(bsize, bsize))

						color.a = 0.6 if on else 0.2
						if layer_index == hovered_index:
							# Add visual feedback when hovering a flag.
							color.a += 0.15

						draw_rect(rect2, color)
						flag_rects.push_back(rect2)

						var font := get_theme_font("font", "Label")
						var font_size := get_theme_font_size("font_size", "Label")
						var offset: Vector2
						offset.y = rect2.size.y * 0.75

						draw_string(font, rect2.position + offset, str(layer_index + 1), HORIZONTAL_ALIGNMENT_CENTER, rect2.size.x, font_size, text_color_on if on else text_color)

						ofs.x += bsize + 1

						layer_index += 1

					ofs.x = block_ofs.x
					ofs.y += bsize + 1

				if layer_index >= layer_count:
					if !flag_rects.is_empty() && (expansion_rows == 0):
						var last_rect := flag_rects[flag_rects.size() - 1]
						arrow_pos = last_rect.end
					break

				var block_size_x := layer_group_size * (bsize + 1)
				block_ofs.x += block_size_x + 3

				if block_ofs.x + block_size_x + 12 > grid_size.x:
					# Keep last valid cell position for the expansion icon.
					if !flag_rects.is_empty() && (expansion_rows == 0):
						var last_rect := flag_rects[flag_rects.size() - 1]
						arrow_pos = last_rect.end
					expansion_rows += 1

					if expanded:
						# Expand grid to next line.
						block_ofs.x = 4
						block_ofs.y += 2 * (bsize + 1) + 3
					else:
						# Skip remaining blocks.
						break

			if (expansion_rows != prev_expansion_rows) && expanded:
				pass
				#refresh_minimum_size() # TODO: doesnt work for some reason, figure out to avoid exess refreshes
			
			if (expansion_rows == 0) && (layer_index == layer_count):
				# Whole grid was drawn, no need for expansion icon.
				return
			
			var arrow := get_theme_icon("arrow", "Tree")
			assert(arrow != null)

			var arrow_color := get_theme_color("highlight_color", "Editor")
			arrow_color.a = 1.0 if expand_hovered else 0.6

			arrow_pos.x += 2.0
			arrow_pos.y -= arrow.get_height()

			var arrow_draw_rect := Rect2(arrow_pos, arrow.get_size())
			expand_rect = arrow_draw_rect
			if expanded:
				arrow_draw_rect.size.y *= -1.0 # Flip arrow vertically when expanded.
			
			var ci := get_canvas_item()
			arrow.draw_rect(ci, arrow_draw_rect, false, arrow_color)

		NOTIFICATION_MOUSE_EXIT: 
			_on_hover_exit()
	

	
	

func set_read_only(p_read_only: bool) -> void:
	read_only = p_read_only
	
	
func refresh_minimum_size() -> Vector2:
	var min_size := get_grid_size()

	# Add extra rows when expanded.
	if expanded:
		var bsize := (min_size.y * 80 / 100) / 2
		for i in range(0, expansion_rows):
			min_size.y += 2 * (bsize + 1) + 3
	
	custom_minimum_size = min_size
	
	return min_size
	
	
func get_tooltip(p_pos: Vector2 = Vector2(0, 0)) -> String: # override
	for i in range(0, flag_rects.size()):
		if i < tooltips.size() && flag_rects[i].has_point(p_pos):
			return tooltips[i];
	return String();
	
	
func _gui_input(p_ev: InputEvent) -> void: # override
	if read_only:
		return
	var mm: InputEventMouseMotion = p_ev as InputEventMouseMotion
	if is_instance_valid(mm):
		_update_hovered(mm.get_position())
		return

	var mb: InputEventMouseButton = p_ev as InputEventMouseButton
	if (is_instance_valid(mb) && mb.get_button_index() == MOUSE_BUTTON_LEFT  && mb.is_pressed()):
		_update_hovered(mb.get_position())
		_update_flag(mb.is_command_or_control_pressed())
	if (is_instance_valid(mb) && mb.get_button_index() == MOUSE_BUTTON_RIGHT  && mb.is_pressed()):
		if hovered_index != INT32_MAX:
			renamed_layer_index = hovered_index
			layer_rename.set_position(get_screen_position() + mb.get_position())
			layer_rename.reset_size()
			layer_rename.popup()
	
	
func set_flag(p_flag: int) -> void:
	value = p_flag;
	queue_redraw()
