tool
extends Reference


const GenericUtils = preload("../utility/generic_utils.gd")
const GardenerUtils = preload("../utility/gardener_utils.gd")
const OctreeManager = preload("../../arborist/mmi_octree/mmi_octree_manager.gd")
const OctreeNode = preload("../../arborist/mmi_octree/mmi_octree_node.gd")
const Greenhouse = preload("../../greenhouse/greenhouse.gd")
const Greenhouse_LODVariant = preload("../../greenhouse/greenhouse_LOD_variant.gd")
const Toolshed = preload("../../toolshed/toolshed.gd")
const Gardener = preload("../../gardener/gardener.gd")


var reference_tree_snapshot:Dictionary = {}
var given_tree_snapshot:Dictionary = {}
var reference_octree_snapshots:Array = []
var given_octree_snapshots:Array = []




func snapshot_tree(node:Node):
	var snapshot = GardenerUtils.snapshot_tree(node)
	if reference_tree_snapshot.empty():
		reference_tree_snapshot = snapshot
	elif given_tree_snapshot.empty():
		given_tree_snapshot = snapshot
	else:
		assert(true, "Both 'last' and 'new' tree snapshots are already defined!")


func snapshot_octrees(octree_managers:Array):
	var snapshot = GardenerUtils.snapshot_octrees(octree_managers)
	if reference_octree_snapshots.empty():
		reference_octree_snapshots = snapshot
	elif given_octree_snapshots.empty():
		given_octree_snapshots = snapshot
	else:
		assert(true, "Both 'last' and 'new' octree snapshots are already defined!")


func check_tree_snapshots(logger, text:String = "") -> Array:
	var tree_discrepancies = GenericUtils.check_values(given_tree_snapshot, reference_tree_snapshot)
	
	logger.info("Found '%d' discrepancies %s %s" % [tree_discrepancies.size(), "in node tree", text])
	if !tree_discrepancies.empty():
		for discrepancy in tree_discrepancies:
			logger.info(str(discrepancy))
		logger.info(given_tree_snapshot)
		logger.info(reference_tree_snapshot)
	
	return tree_discrepancies


func check_octree_snapshots(logger, text:String = "") -> Array:
	var octree_discrepancies = GenericUtils.check_values(given_octree_snapshots, reference_octree_snapshots)
	
	logger.info("Found '%d' discrepancies %s %s" % [octree_discrepancies.size(), "in octree", text])
	if !octree_discrepancies.empty():
		for discrepancy in octree_discrepancies:
			logger.info(str(discrepancy))
		logger.info(given_octree_snapshots)
		logger.info(reference_octree_snapshots)
	
	return octree_discrepancies
