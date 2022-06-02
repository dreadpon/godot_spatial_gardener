tool


const GenericUtils = preload("../utility/generic_utils.gd")
const PlantUtils = preload("../utility/plant_utils.gd")
const Greenhouse = preload("../../greenhouse/greenhouse.gd")




static func check_snapshots(list_index:int, given:Greenhouse, reference:Greenhouse, logger, text):
	return GenericUtils.find_discrepancies(
		list_index, PlantUtils.snapshot_greenhouse(given), PlantUtils.snapshot_greenhouse(reference), logger, text)
