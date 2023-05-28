@tool
extends RefCounted


var type:String = ""
var origin:Vector3 = Vector3()
var basis:Basis = Basis()
var extent:float = 0.0




func _init(_type:String = "", _origin:Vector3 = Vector3(), _basis:Basis = Basis(), _extent:float = 0.0):
	type = _type
	origin = _origin
	basis = _basis
	extent = _extent
