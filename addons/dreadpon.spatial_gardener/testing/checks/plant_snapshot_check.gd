@tool
class_name PlantSnapshotCheck



static func check_snapshots(list_index:int, given:Greenhouse, reference:Greenhouse, logger, text):
	return GenericUtils.find_discrepancies(
		list_index, PlantUtils.snapshot_greenhouse(given), PlantUtils.snapshot_greenhouse(reference), logger, text)
