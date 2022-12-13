tool
extends "stroke_handler.gd"


#-------------------------------------------------------------------------------
# Make painting changes by manually supplying data
#-------------------------------------------------------------------------------

# Meant to be used from code to add or remove instances


func _init().(
	null, [], [], null, null, -1):
	
	set_meta("class", "SH_Manual")


func add_instance(placement: Vector3, surface_normal: Vector3, transform: Transform, plant_index: int, painting_changes: PaintingChanges):
	var placement_transform:PlacementTransform = PlacementTransform.new(placement, surface_normal, transform)
	painting_changes.add_change(PaintingChanges.ChangeType.APPEND, plant_index, placement_transform, placement_transform) 


func remove_instance(placement_transform: PlacementTransform, plant_index: int, painting_changes: PaintingChanges):
	painting_changes.add_change(PaintingChanges.ChangeType.ERASE, plant_index, placement_transform, placement_transform)
