tool
extends Node


#-------------------------------------------------------------------------------
# To use this converter:
# 1. Make sure the plugin is updated to the most recent version
# 2. Copy your scenes to addons/dreadpon.spatial_gardener/scene_converter/input_scenes folder.
# 	- Make sure they have a plain text scene file format (.tscn).
# 	- The scene converter automatically makes backups of your scenes. But you should make your own, in case anything goes wrong.
# 3. Editor might scream that there are resources missing. This is expected.
# 	- You might see a message that some plugin scripts are missing. Ignore, since some things *did* get removed in a plugin.
# 	- That's why you should *not* open these scenes for now.
# 4. Open the scene found at addons/dreadpon.spatial_gardener/scene_converter/scene_converter.tscn.
# 5. Launch it (F6 by default): it will start the conversion process.
# 	- The process takes about 1-10 minutes per scene, depending on it's size.
# 6. If any errors occured, you'll be notified in the console.
# 	- The editor will freeze for a while: the best way to keep track of your progress is by launching the editor from console 
#	- (or by running Godot_v***-stable_win64_console.cmd included in the official download).
# 7. If conversion was successful, grab your converted scenes from addons/dreadpon.spatial_gardener/scene_converter/output_scenes folder 
#	and move them to their intended places.
# 8. You should be able to launch your converted scenes now.
# 	- Optionally, you might have to relaunch the project and re-enable the plugin.
# 	- Make sure to move backups elsewhere before committing to source control.
#
# NOTE: your original scenes (in 'input_scenes' folder) should be intact
#		but please keep a backup elsewhere just in case
#
# NOTE: to see the conversion status in real-time
#		you'll need to launch editor with console, which you can then inspect
#		this is done by launching Godot executable from native console/terminal
#-------------------------------------------------------------------------------


const Types = preload('converter_types.gd')
const Globals = preload("../utility/globals.gd")
const C_1_To_2 = preload('converters/c_1_to_2.gd')
const FunLib = preload("../utility/fun_lib.gd")
const Gardener = preload("../gardener/gardener.gd")
const Logger = preload('../utility/logger.gd')
const ConvertDialog_SCN = preload("convert_dialog.tscn")

const number_char_list = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '-']

enum RunMode {RECREATE, DRY, CONVERT}

var logger = null
var conversion_map: Dictionary = {
	1: {'target': 2, 'script': C_1_To_2.new()}
}
var run_mode = RunMode.CONVERT
var _base_control: Control = null
var _convert_dialog = null
var _result_dialog: AcceptDialog = null




#-------------------------------------------------------------------------------
# Lifecycle and events
#-------------------------------------------------------------------------------


func setup(__base_control: Control):
	_base_control = __base_control
	_scan_for_outdated_scenes()


func destroy():
	_base_control.remove_child(_convert_dialog)


func _hide_dialog():
	_convert_dialog.hide()


func _on_project_settings_changed():
	_scan_for_outdated_scenes()


func _set_dont_scan_setting(val):
	ProjectSettings.set("dreadpons_spatial_gardener/plugin/scan_for_outdated_scenes", !val)


func _ready():
	if Engine.editor_hint: return
	_convert_from_input_dir()




#-------------------------------------------------------------------------------
# Conversion initiation
#-------------------------------------------------------------------------------


func _convert_from_input_dir():
	var self_base_dir = get_script().resource_path.get_base_dir()
	var in_path = self_base_dir + '/input_scenes'
	var out_path = self_base_dir + '/output_scenes'
	var canditate_scenes = _get_candidate_scenes(in_path, false)
	if canditate_scenes.empty(): return
	
	_run_conversion(canditate_scenes, true, out_path)


func _scan_for_outdated_scenes():
	if !FunLib.get_setting_safe("dreadpons_spatial_gardener/plugin/scan_for_outdated_scenes", true): return
	var canditate_scenes = _get_candidate_scenes('res://')
	if canditate_scenes.empty(): return
	
	if !_convert_dialog:
		_convert_dialog = ConvertDialog_SCN.instance()
		_convert_dialog.connect('confirm_pressed', self, '_convert_from_dialog')
		_convert_dialog.connect('confirm_pressed', self, '_hide_dialog')
		_convert_dialog.connect('cancel_pressed', self, '_hide_dialog')
		_convert_dialog.connect('dont_ask_again_toggled', self, '_set_dont_scan_setting')
	if _convert_dialog.get_parent() != _base_control:
		_base_control.add_child(_convert_dialog)
	
	if !_result_dialog:
		_result_dialog = AcceptDialog.new()
		_result_dialog.window_title = 'Spatial Gardener conversion finished'
		
	if _result_dialog.get_parent() != _base_control:
		_base_control.add_child(_result_dialog)
	
	_convert_dialog.add_scenes(canditate_scenes)
	_convert_dialog.popup_centered()


func _convert_from_dialog():
	var result = _run_conversion(_convert_dialog.get_selected_scenes(), _convert_dialog.should_mk_backups())
	_result_dialog.dialog_text = (
"""Spatial Gardener conversion finished.
Please check the console/output for errors to see if conversion went successfully.
Don\'t forget to move the backups elsewhere before committing to version control.""")
	_result_dialog.popup_centered()




#-------------------------------------------------------------------------------
# Scene candidate gathering
#-------------------------------------------------------------------------------


func _get_candidate_scenes(root_dir: String, check_gardeners: bool = true) -> Array:
	var scene_file_paths = []
	var gardener_file_paths = []
	
	FunLib.iterate_files(root_dir, true, self, 'add_scene_file', scene_file_paths)
	
	if !check_gardeners:
		return scene_file_paths

	var file = File.new()
	var text = ''
	var gardener_regex = RegEx.new()
	gardener_regex.compile('"class": "Gardener"')
	var storage_regex = RegEx.new()
	storage_regex.compile('storage_version = ([0-9])*?\n')
	
	for scene_file in scene_file_paths:
		file.open(scene_file, File.READ)
		text = file.get_as_text()
		file.close()
		
		var results = gardener_regex.search_all(text)
		if results.empty(): continue
		results = storage_regex.search_all(text)
		if results.empty(): 
			gardener_file_paths.append(scene_file)
			continue
		
		for result in results:
			if int(result.strings[1]) != Gardener.get_storage_ver():
				gardener_file_paths.append(scene_file)
				continue
	
	return gardener_file_paths


func add_scene_file(file_path: String, scenes: Array):
	if file_path.get_extension() == 'tscn':
		scenes.append(file_path)




#-------------------------------------------------------------------------------
# High-level conversion process
#-------------------------------------------------------------------------------


func _run_conversion(in_filepaths: Array, mk_backups: bool = true, out_base_dir: String = '') -> bool:
	var timestamp = Time.get_datetime_string_from_system(false, true).replace(' ', '_').replace(':', '.')
	logger = Logger.get_for(self, '', 'user://sg_tscn_conversion_%s.txt' % [timestamp])
	
	logger.info('Found %d valid scenes for conversion' % [in_filepaths.size()])
	
	var backup_dir := Directory.new()
	for in_filepath in in_filepaths:
		if mk_backups:
			var num = 0
			while backup_dir.file_exists('%s.backup_%d' % [in_filepath, num]):
				num += 1
			backup_dir.copy(in_filepath, '%s.backup_%d' % [in_filepath, num])
		
		var out_filepath = in_filepath
		if !out_base_dir.empty():
			out_filepath = out_base_dir + '/' + in_filepath.get_file()
		
		var start_time = OS.get_ticks_msec()
		logger.info('Converting scene: "%s", to file: %s, backup: %s' % [in_filepath, out_filepath, mk_backups])
		
		var in_size = 0
		if run_mode == RunMode.CONVERT || run_mode == RunMode.RECREATE:
			var file = File.new()
			file.open(in_filepath, File.READ)
			in_size = file.get_len() * 0.000001
			file.close()
		
		var ext_res := {}
		var sub_res := {}
		logger.info('Parsing scene...')
		var parsed_scene = parse_scene(in_filepath, ext_res, sub_res)
		
		if run_mode == RunMode.CONVERT || run_mode == RunMode.DRY:
			var storage_vers = get_vers(parsed_scene)
			if storage_vers.size() < 1:
				logger.warn('No Gardeners found in this scene')
				continue
			elif storage_vers.size() > 1:
				logger.error('Gardeners in this scene have multiple mismatched storage versions. All Gardeners must be of the same version')
				continue
			
			var curr_ver = storage_vers[0]
			while curr_ver != Gardener.get_storage_ver():
				var conversion_data = conversion_map[curr_ver]
				logger.info('Converting Gardener data from storage v.%s to v.%s...' % [curr_ver, conversion_data.target])
				conversion_data.script.convert_gardener(parsed_scene, run_mode, ext_res, sub_res)
				curr_ver = conversion_data.target
		
		if run_mode == RunMode.CONVERT || run_mode == RunMode.RECREATE:
			logger.info('Reconstructing scene...')
			reconstruct_scene(parsed_scene, out_filepath)
		
		var time_took = float(OS.get_ticks_msec() - start_time) / 1000
		logger.info('Finished converting scene: "%s"' % [in_filepath])
		logger.info('Took: %.2fs' % [ time_took])
		
		if run_mode == RunMode.CONVERT || run_mode == RunMode.RECREATE:
			var file = File.new()
			file.open(out_filepath, File.READ)
			var out_size = file.get_len() * 0.000001
			file.close()
			
			logger.info('Size changed from %.2fMb to %.2fMb' % [in_size, out_size])
	
	logger.info('Finished %d scene(s) conversions' % [in_filepaths.size()])
	return true


func get_vers(parsed_scene):
	var vers = []
	for section in parsed_scene:
		if section.props.get('__meta__', {}).get('class', '') == 'Gardener':
			var ver = section.props.get('storage_version', 1)
			if vers.has(ver): continue
			vers.append(ver)
	return vers


func reconstruct_scene(parsed_scene: Array, out_path: String):
	var file = File.new()
	var err = file.open(out_path, File.WRITE)
	if err != OK:
		logger.error('Unable to write to file "%s", with error: %s' % [out_path, Globals.get_err_message(err)])
	
	var total_sections = float(parsed_scene.size())
	var progress_milestone = 0
	
	var last_type = ''
	var section_num = 0
	for section in parsed_scene:
		
		if ['sub_resource', 'node'].has(last_type) || !last_type.empty() && last_type != section.type:
			file.store_line('')
		
		var line = '[' + section.type
		for section_prop in section.header:
			line += ' %s=%s' % [section_prop, Types.get_val_for_export(section.header[section_prop])]
		line += ']'
		file.store_line(line)
		
		for prop in section.props:
			line = '%s = %s' % [prop, Types.get_val_for_export(section.props[prop])]
			file.store_line(line)
		
		last_type = section.type
		
		section_num += 1
		var file_progress = floor(section_num / total_sections * 100)
		if file_progress >= progress_milestone * 10:
			logger.info('Reconstructed: %02d%%' % [progress_milestone * 10])
			progress_milestone += 1
	
	file.close()




#-------------------------------------------------------------------------------
# Low-level parsing
#-------------------------------------------------------------------------------


func parse_scene(filepath: String, ext_res: Dictionary = {}, sub_res: Dictionary = {}) -> Array:
	var result := []
	var file: File = File.new()
	var err = file.open(filepath, File.READ)
	if err != OK:
		logger.error('Unable to open file "%s", with error: %s' % [filepath, Globals.get_err_message(err)])
	
	var file_len = float(file.get_len())
	var progress_milestone = 0
	
	var section_string: PoolStringArray = PoolStringArray()
	var section_active := false
	var section = {}
	var sections_parts = []
	var open_square_brackets = 0
	var header_start = 0
	var header_active = false
	var first_line = true
	var line_byte_offset = 1
	
	var line: String
	while !file.eof_reached():
		line = file.get_line()
		var no_brackets = open_square_brackets == 0
		var position = file.get_position()
		var line_size = line.to_utf8().size() + line_byte_offset
		
		# If first line size not equal to position - then we're dealing with CRLF
		if first_line && position != line_size:
			line_byte_offset = 2
			line_size = line.to_utf8().size() + line_byte_offset
		
		open_square_brackets += line.count('[')
		open_square_brackets -= line.count(']')
		if line.begins_with('['):
			header_active = true
			header_start = position - line_size
		
		if header_active && open_square_brackets == 0:
			open_square_brackets = 0
			header_active = false
			
			var header_end = position
			file.seek(header_start)
			var header_str = file.get_buffer(header_end - header_start).get_string_from_utf8().strip_edges()
			file.seek(header_end)
			
			section = {'type': '', 'header': {}, 'props': {}}
			sections_parts = Array(header_str.trim_prefix('[').trim_suffix(']').split(' '))
			section.type = sections_parts.pop_front()
			section.header = parse_resource(PoolStringArray(sections_parts).join(' ') + ' ', ' ')
			result.append(section)
			section_string = PoolStringArray()
			
			if section.type == 'ext_resource':
				ext_res[section.header.id] = section
			elif section.type == 'sub_resource':
				sub_res[section.header.id] = section
			
			section_active = true
		
		elif section_active && line.strip_escapes().empty() && !result.empty():
			result[-1].props = parse_resource(section_string.join(''))
			section_active = false
		
		elif !line.strip_escapes().empty():
			section_string.append(line + '\n')
		
		var file_progress = floor(position / file_len * 100)
		if file_progress >= progress_milestone * 10:
			logger.info('Parsed: %02d%%' % [progress_milestone * 10])
			progress_milestone += 1
		
		if first_line:
			first_line = false
	
	return result


func parse_resource(res_string: String, separator: String = '\n') -> Dictionary:
	if res_string.empty(): return {}
	var result := {}
	var tokens := tokenize_string(res_string, separator)
	result = tokens_to_dict(tokens)
	return result


func tokenize_string(string: String, separator: String = '\n') -> Array:
	var tokens = Array()
	var current_token = Types.Tokens.NONE
	var character = ''
	
	var status_bundle = {
		'idx': 0,
		'string': string,
		'last_tokenized_idx': 0
	}
	
	for idx in string.length():
		status_bundle.idx = idx
		
		character = string[idx]
		
		if current_token == Types.Tokens.NONE:
			# All chars so far were numerical, and next one IS NOT
			if ((string.length() <= idx + 1 || !number_char_list.has(string[idx + 1]))
				&& str_has_only_numbers(str_last_inclusive(status_bundle))):
					# Number string has a dot - is a float
					if str_last_inclusive_stripped(status_bundle).find('.') >= 0:
						tokens.append(Types.TokenVal.new(Types.Tokens.VAL_REAL, float(str_last_inclusive_stripped(status_bundle))))
					# Else - int
					else:
						tokens.append(Types.TokenVal.new(Types.Tokens.VAL_INT,int(str_last_inclusive_stripped(status_bundle))))
					status_bundle.last_tokenized_idx = idx + 1
			
			if character == '=':
				var prop_name = str_last_stripped(status_bundle)
				while tokens.size() > 0:
					var token_val = tokens[-1]
					if token_val.type == Types.Tokens.STMT_SEPARATOR: break
					tokens.pop_back()
					prop_name = str(token_val.val) + prop_name
				tokens.append(Types.TokenVal.new(Types.Tokens.PROP_NAME, prop_name))
				tokens.append(Types.TokenVal.new(Types.Tokens.EQL_SIGN, character))
				status_bundle.last_tokenized_idx = idx + 1
			elif character == '"' && (idx == 0 || string[idx - 1] != '\\'):
				current_token = Types.Tokens.DBL_QUOTE
				status_bundle.last_tokenized_idx = idx + 1
			elif character == ',':
				tokens.append(Types.TokenVal.new(Types.Tokens.COMMA, character))
				status_bundle.last_tokenized_idx = idx + 1
			elif character == ':':
				tokens.append(Types.TokenVal.new(Types.Tokens.COLON, character))
				status_bundle.last_tokenized_idx = idx + 1
			
			# Parentheses not representing a "struct" are impossible
			# So we don't parse them separately
			elif character == '[':
				tokens.append(Types.TokenVal.new(Types.Tokens.OPEN_SQR_BRKT, character))
				status_bundle.last_tokenized_idx = idx + 1
			elif character == ']':
				tokens.append(Types.TokenVal.new(Types.Tokens.CLSD_SQR_BRKT, character))
				status_bundle.last_tokenized_idx = idx + 1
			elif character == '{':
				tokens.append(Types.TokenVal.new(Types.Tokens.OPEN_CLY_BRKT, character))
				status_bundle.last_tokenized_idx = idx + 1
			elif character == '}':
				tokens.append(Types.TokenVal.new(Types.Tokens.CLSD_CLY_BRKT, character))
				status_bundle.last_tokenized_idx = idx + 1
			
			elif character == '(':
				current_token = Types.Tokens.VAL_STRUCT
			
			elif ['false', 'true'].has(str_last_inclusive_stripped(status_bundle).to_lower()):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_BOOL, Types.to_bool(str_last_inclusive_stripped(status_bundle))))
				status_bundle.last_tokenized_idx = idx + 1
			elif str_last_inclusive_stripped(status_bundle) == 'null':
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_NIL, null))
				status_bundle.last_tokenized_idx = idx + 1
			
			elif character == separator:
				tokens.append(Types.TokenVal.new(Types.Tokens.STMT_SEPARATOR, ''))
		
		elif current_token == Types.Tokens.DBL_QUOTE:
			if character == '"' && (idx == 0 || string[idx - 1] != '\\'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_STRING, str_last(status_bundle)))
				status_bundle.last_tokenized_idx = idx + 1
				current_token = Types.Tokens.NONE
		
		elif current_token == Types.Tokens.VAL_STRUCT && character == ')':
			var str_struct = str_last_inclusive_stripped(status_bundle)
			if str_struct.begins_with('SubResource'):
				tokens.append(Types.TokenVal.new(Types.Tokens.SUB_RES, Types.SubResource.new(int(str_struct))))
			elif str_struct.begins_with('ExtResource'):
				tokens.append(Types.TokenVal.new(Types.Tokens.EXT_RES, Types.ExtResource.new(int(str_struct))))
			elif str_struct.begins_with('Vector2'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_VECTOR2, Types.PropStruct.new(str_struct)))
			elif str_struct.begins_with('Rect'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_RECT, Types.PropStruct.new(str_struct)))
			elif str_struct.begins_with('Vector3'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_VECTOR3, Types.PS_Vector3.new(str_struct)))
			elif str_struct.begins_with('Transform2D'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_TRANSFORM2D, Types.PropStruct.new(str_struct)))
			elif str_struct.begins_with('Plane'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_PLANE, Types.PropStruct.new(str_struct)))
			elif str_struct.begins_with('Quat'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_QUAT, Types.PropStruct.new(str_struct)))
			elif str_struct.begins_with('AABB'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_AABB, Types.PropStruct.new(str_struct)))
			elif str_struct.begins_with('Basis'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_BASIS, Types.PropStruct.new(str_struct)))
			elif str_struct.begins_with('Transform'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_TRANSFORM, Types.PS_Transform.new(str_struct)))
			elif str_struct.begins_with('Color'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_COLOR, Types.PropStruct.new(str_struct)))
			elif str_struct.begins_with('NodePath'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_NODE_PATH, Types.PropStruct.new(str_struct)))
			elif str_struct.begins_with('PoolByteArray'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_RAW_ARRAY, Types.PropStruct.new(str_struct)))
			elif str_struct.begins_with('PoolIntArray'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_INT_ARRAY, Types.PropStruct.new(str_struct)))
			elif str_struct.begins_with('PoolRealArray'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_REAL_ARRAY, Types.PropStruct.new(str_struct)))
			elif str_struct.begins_with('PoolStringArray'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_STRING_ARRAY, Types.PropStruct.new(str_struct)))
			elif str_struct.begins_with('PoolVector2Array'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_VECTOR2_ARRAY, Types.PropStruct.new(str_struct)))
			elif str_struct.begins_with('PoolVector3Array'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_VECTOR3_ARRAY, Types.PropStruct.new(str_struct)))
			elif str_struct.begins_with('PoolColorArray'):
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_COLOR_ARRAY, Types.PropStruct.new(str_struct)))
			else:
				tokens.append(Types.TokenVal.new(Types.Tokens.VAL_STRUCT, str_last_inclusive_stripped(status_bundle)))
			status_bundle.last_tokenized_idx = idx + 1
			current_token = Types.Tokens.NONE
	
	return tokens


func str_last_stripped(status_bundle: Dictionary) -> String:
	return str_last(status_bundle).strip_edges()


func str_last(status_bundle: Dictionary) -> String:
	return status_bundle.string.substr(status_bundle.last_tokenized_idx, status_bundle.idx - status_bundle.last_tokenized_idx)


func str_last_inclusive_stripped(status_bundle: Dictionary) -> String:
	return str_last_inclusive(status_bundle).strip_edges()


func str_last_inclusive(status_bundle: Dictionary) -> String:
	return status_bundle.string.substr(status_bundle.last_tokenized_idx, status_bundle.idx - status_bundle.last_tokenized_idx + 1)


func str_has_only_numbers(string: String) -> bool:
	string = string.strip_escapes().strip_edges()
	if string.empty(): return false
	
	for character in string:
		if !number_char_list.has(character):
			return false
	return true


func tokens_to_dict(tokens: Array) -> Dictionary:
	var result := {}
	var keys := []
	var nest_level := 1
	var values := [result]
	
	var dest_string = ''
	
	var idx := 0
	while idx < tokens.size():
		var push_to_values := false
		var token: Types.TokenVal = tokens[idx]
		match token.type:
			Types.Tokens.EQL_SIGN, Types.Tokens.COLON:
				var key = values.pop_back()
				keys.append(key)
			Types.Tokens.CLSD_CLY_BRKT:
				if values.size() > nest_level:
					push_to_values = true
				nest_level -= 1
			Types.Tokens.CLSD_SQR_BRKT:
				if values.size() > nest_level:
					push_to_values = true
				nest_level -= 1
			Types.Tokens.COMMA:
				push_to_values = true
			
			Types.Tokens.PROP_NAME:
				values.append(token.val)
			
			Types.Tokens.OPEN_CLY_BRKT:
				values.append({})
				nest_level += 1
			Types.Tokens.OPEN_SQR_BRKT:
				values.append([])
				nest_level += 1
			
			Types.Tokens.STMT_SEPARATOR:
				if tokens.size() <= idx + 1 || tokens[idx + 1].is_token(Types.Tokens.PROP_NAME):
					push_to_values = true
			
			_:
				values.append(token.val)
			
		if push_to_values:
			var destination = values[-2]
			var val = values.pop_back()
			if destination is Array:
				destination.append(val)
			elif !keys.empty():
				var key = keys.pop_back()
				destination[key] = val
		
		idx += 1
	
	return result
