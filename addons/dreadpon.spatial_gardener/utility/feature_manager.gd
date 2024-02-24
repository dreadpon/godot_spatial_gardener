extends RefCounted
class_name DPON_FM

static var ED_EditorUndoRedoManager = null
static var ED_EditorFileDialog = null

static var _class_map: Dictionary = {}




static func setup():
	ED_EditorUndoRedoManager = get_native_class("EditorUndoRedoManager")
	ED_EditorFileDialog = get_native_class("EditorFileDialog")
	
	_class_map = {}
	if ED_EditorUndoRedoManager:
		_class_map["EditorUndoRedoManager"] = ED_EditorUndoRedoManager
	if ED_EditorFileDialog:
		_class_map["EditorFileDialog"] = ED_EditorFileDialog


static func is_instance_of_ed(instance: Variant, str_lass_name: String) -> bool:
	if _class_map.has(str_lass_name):
		return is_instance_of(instance, _class_map[str_lass_name])
	return false


static func get_native_class(str_lass_name: String) -> Variant:
	if ClassDB.class_exists(str_lass_name):
		var script := GDScript.new()
		var func_name := &"get_class_by_str"
		script.source_code = "@tool\nextends RefCounted\nstatic func %s() -> Variant: return %s\n" % [func_name, str_lass_name]
		script.reload()
		return script.call(func_name)
	return null
