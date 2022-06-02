tool
extends Resource


#-------------------------------------------------------------------------------
# A resource that stores a placement (initial position), surface normal
# Final Transform and an occupied octree octant (what part of the 2x2x2 cube it's in)
# Ideally this should be a struct to avoid the overhead of saving/loading thousands of small resources
#-------------------------------------------------------------------------------

# TODO find out if there *is* any overhead to this and if yes - make this a C++ struct or at least a GDScript dictionary


# A designated position for an instance
export var placement:Vector3 = Vector3()
# A normal of the surface
export var surface_normal:Vector3 = Vector3()
# An actual transform derived from placement including random offsets, rotations, scaling, etc.
export var transform:Transform = Transform()
# Occupied octant is mostly used to quick access the child node of an octree node
# E.g. when aplying PaintingChanges
export var octree_octant:int = 0




func _init(_placement:Vector3 = Vector3(), _surface_normal:Vector3 = Vector3(), _transform:Transform = Transform(), _octree_octant:int = 0):
	set_meta("class", "PlacementTransform")
	resource_name = "PlacementTransform"
	
	placement = _placement
	surface_normal = _surface_normal
	transform = _transform
	octree_octant = _octree_octant
