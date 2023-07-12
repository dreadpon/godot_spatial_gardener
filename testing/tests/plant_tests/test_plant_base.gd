@tool
extends "../test_base.gd"


const PlantUtils = preload("../../utility/plant_utils.gd")
const PlantSnapshotCheck = preload("../../checks/plant_snapshot_check.gd")
const Greenhouse = preload("res://addons/dreadpon.spatial_gardener/greenhouse/greenhouse.gd")


@export var save_path:String = "" # (String, DIR)




func load_greenhouses() -> Array:
	return GenericUtils.load_sequential_resources_in_array(save_path, "greenhouse_")


func find_discrepancies(list_index:int, given, ref, text) -> bool:
	return PlantSnapshotCheck.check_snapshots(list_index, given, ref, logger, text)
