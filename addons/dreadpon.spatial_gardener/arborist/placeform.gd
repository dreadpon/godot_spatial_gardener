tool
extends Reference


#-------------------------------------------------------------------------------
# PLACEment transFORM
# A pseudo-struct meant to store a placement (initial position), surface normal
# Final Transform and an occupied octree octant (what part of the 2x2x2 cube it's in)
#
# Originally was a resource, but after some quick tests, the overhead of having 
# Thousands of Resources as simple containers became apparent
# It was decided to use an Array as a fastest and most compact built-in container
#
# This script provides an function library to more easily construct such arrays
# And provide access to methods that were formerly part of this Resource
#-------------------------------------------------------------------------------


# [0] - placement,
# [1] - surface_normal
# [2] - transform
# [3] - octree_octant


static func mk(placement:Vector3 = Vector3(), surface_normal:Vector3 = Vector3(), transform:Transform = Transform(), octree_octant:int = 0) -> Array:
	return [
		# A designated position for an instance
		placement, 
		# A normal of the surface
		surface_normal,
		# An actual transform derived from placement including random offsets, rotations, scaling, etc.
		transform,
		# Occupied octant is mostly used to quick access the child node of an octree node
		# E.g. when aplying PaintingChanges 
		octree_octant
	]


static func to_str(placeform: Array) -> String:
	return '[%s, %s, %s, %s, %d]' % [str(placeform[0]), str(placeform[1]), str(placeform[2].basis), str(placeform[2].origin), placeform[3]]


static func get_origin_offset(placeform: Array) -> float:
	var difference = placeform[2].origin - placeform[0]
	var offset = placeform[1].dot(difference.normalized()) * difference.length()
	return offset


static func set_placement_from_origin_offset(placeform: Array, offset: float):
	placeform[0] = placeform[2].origin - placeform[1] * offset
	return placeform
