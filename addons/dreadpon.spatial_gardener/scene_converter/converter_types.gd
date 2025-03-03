extends RefCounted


enum Tokens {
	NONE,
	
	STMT_SEPARATOR,
	
	EQL_SIGN,
	OPEN_PRNTS,
	CLSD_PRNTS,
	OPEN_TYPED_ARRAY,
	CLSD_TYPED_ARRAY,
	OPEN_SQR_BRKT,
	CLSD_SQR_BRKT,
	OPEN_CLY_BRKT,
	CLSD_CLY_BRKT,
	SGL_QUOTE,
	AMP_DBL_QUOTE,
	DBL_QUOTE,
	COLON,
	COMMA,
	
	SUB_RES,
	EXT_RES,
	PROP_NAME,
	
	VAL_NIL,
	VAL_BOOL,
	VAL_INT,
	VAL_REAL,
	VAL_STRING,
	VAL_STRING_NAME,
	VAL_VECTOR2,
	VAL_RECT,
	VAL_VECTOR3,
	VAL_TRANSFORM2D,
	VAL_PLANE,
	VAL_QUAT,
	VAL_AABB,
	VAL_BASIS,
	VAL_TRANSFORM,
	VAL_COLOR,
	VAL_NODE_PATH,
	VAL_RID,
	VAL_OBJECT,
	VAL_DICTIONARY,
	VAL_ARRAY,
	VAL_RAW_ARRAY,
	VAL_INT_ARRAY,
	VAL_REAL_ARRAY,
	VAL_STRING_ARRAY,
	VAL_VECTOR2_ARRAY,
	VAL_VECTOR3_ARRAY,
	VAL_COLOR_ARRAY,
	VAL_TYPED_ARRAY,
	
	VAL_STRUCT,
}




static func get_val_for_export(val):
	match typeof(val):
		TYPE_NIL:
			return 'null'
		TYPE_STRING:
			return '"%s"' % [val]
		TYPE_STRING_NAME:
			return '&"%s"' % [val]
		TYPE_FLOAT:
			if is_equal_approx(val - int(val), 0.0):
				return '%d.0' % [int(val)]
			return str(val)
		TYPE_BOOL:
			return 'true' if val == true else 'false'
		TYPE_ARRAY:
			var is_typed = val.size() > 0 && val[0] is TypedArrayType
			var string = '['
			# This is a hack to simplify storage and retrieval of array's type
			if is_typed:
				string = "Array[%s]([" % [val.pop_front()]
			for element in val:
				string += get_val_for_export(element) + ', '
			if val.size() != 0:
				string = string.trim_suffix(', ')
			if is_typed:
				string += '])'
			else:
				string += ']'
			return string
		TYPE_DICTIONARY:
			var string = '{\n'
			for key in val:
				string += '%s: %s,\n' % [get_val_for_export(key), get_val_for_export(val[key])]
			if val.size() != 0:
				string = string.trim_suffix(',\n')
			string += '\n}'
			return string
	return str(val)


static func to_bool(string: String):
	return string.to_lower() == 'true'




class TokenVal extends RefCounted:
	var type: int = Tokens.NONE
	var val = null
	func _init(__type: int = Tokens.NONE, __val = null):
		type = __type
		val = __val
	func _to_string():
		return "[%s:'%s']" % [Tokens.keys()[type], str(val)]
	func is_token(token_type: int):
		return type == token_type




class PropStruct extends RefCounted:
	var content = null
	func _init(__content = null):
		content = __content
	func _to_string():
		return str(content)


class PS_Vector3 extends PropStruct:
	func _init(__content = null):
		super(__content)
	func variant():
		var split = content.trim_prefix('Vector3( ').trim_suffix(' )').split(', ')
		return Vector3(split[0], split[1], split[2])


class PS_Transform extends PropStruct:
	func _init(__content = null):
		super(__content)
	func variant():
		var split = content.trim_prefix('Transform3D( ').trim_suffix(' )').split(', ')
		return Transform3D(Vector3(split[0], split[3], split[6]), Vector3(split[1], split[4], split[7]), Vector3(split[2], split[5], split[8]), Vector3(split[9], split[10], split[11]))



class SubResource extends PropStruct:
	var id: String = ""
	func _init(__id: String = ""):
		id = __id.trim_prefix('SubResource("').trim_suffix('")')
	func _to_string():
		return 'SubResource("%s")' % [id]


class ExtResource extends SubResource:
	func _init(__id: String = ""):
		id = __id.trim_prefix('ExtResource("').trim_suffix('")')
	func _to_string():
		return 'ExtResource("%s")' % [id]


class TypedArrayType extends RefCounted:
	var type: String = ""
	func _init(__type: String = ""):
		type = __type
	func _to_string():
		return '%s' % [type]
