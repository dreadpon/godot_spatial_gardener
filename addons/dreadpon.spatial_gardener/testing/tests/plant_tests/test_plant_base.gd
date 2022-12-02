@tool
extends "../test_base.gd"


@export var save_path:String = "" # (String, DIR)




func load_greenhouses() -> Array:
	return GenericUtils.load_sequential_resources_in_array(save_path, "greenhouse_")


func find_discrepancies(list_index:int, given, reference, text) -> bool:
	return PlantSnapshotCheck.check_snapshots(list_index, given, reference, logger, text)
