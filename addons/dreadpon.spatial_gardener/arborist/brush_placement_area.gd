tool
extends Reference


#-------------------------------------------------------------------------------
# A helper class that creates a placement area (grid)
# And makes sure all instances of a given plant are evenly spaced
#-------------------------------------------------------------------------------

# It uses a 2D grid-based algorithm to maintain both:
	# close-to-desired instance density
	# an even instance distribution
# This article was used as a main reference (grid uses a simple logic and gives good-enough results)
	# https://www.gamedeveloper.com/disciplines/random-scattering-creating-realistic-landscapes
# However, I was not able to derive a solution that creates a grid that evenly projects on a surface of any angle
	# When you approach 45 degrees you start seeing bigger spacing, which becomes unusable by 90 degrees
	# So I thought of trying to project a 3D grid, but that raised a lot of questions on it's own
	# This is still an open question really
# So I dug through some code online and decided on a system I discuss in BrushPlacementArea section

# Algorithm:
	# Use the brush radius, position and the surface normal under it's center to describe a flat circle in 3D space
	# This circle provides a plane and bounds for us to generate the transforms. Most other operations operate in 2D space aligned to said plane
	# Generate a virtual 2D grid with distance between points representing the plant density (less density == bigger distance)
	# Find all "overlapping" plants of the same type in the sphere's radius
		# We only check if the placements (origin positions) of plants are within the sphere. No actual boundary tests
	# Add a max instance check (how many instances total can fit in a circle) and pad the max distance from center slightly OUTSIDE the circle
		# Last one is needed to prevent spawning at half-distance near the circle's edge
	# Project the overlaps to our plane and snap them to the closest point on the grid
		# These grid points become occupied and cannot spawn a new instance
	# All the points that remain will spawn an instance
	# Add a random jitter to each placement (it should be smaller than 0.5 to prevent occasional overlap)
	# Get the raycast start and end positions
		# They are aligned to the plane's normal and clamped at the sphere's bounds
			# Last one prevents out raycast from going outside the sphere
	# Back in the StrokeHandler, use these positions to raycast to surface and determine actual placement positions

# The problem with this method is that the grid CAN and WILL be generated at uneven intervals as the brush moves
# An example, where "( )" - last grid, "[ ]" - current grid, "P" - point
	# (P)(P)
	# (P)(P)    <- align
	#   [P][P]  <- align
	#   [P][P]
	#    /\
	#    do not align
# That leads to some points spawning closer than they should
# While not ideal, this is somewhat mitigated with max instances check
# And snapping brush to the virtual grid
# Ideally I would like the grid to be independent from the brush position
	# But I don't know how to accurately project 3D grid points on an angled surface while keeping them EVENLY SPACED no matter the angle
	# 2D grids give me a close enough result

# TODO Write an article discussing this method that is actually readable by a normal human being


const Globals = preload("../utility/globals.gd")
const FunLib = preload("../utility/fun_lib.gd")
const Logger = preload("../utility/logger.gd")
const MMIOctreeManager = preload("mmi_octree/mmi_octree_manager.gd")
const MMIOctreeNode = preload("mmi_octree/mmi_octree_node.gd")


var sphere_pos:Vector3 = Vector3.ZERO
var sphere_radius:float = 0.0
var sphere_diameter:float = 0.0

var plane_axis_vectors:Array = []
var point_distance:float = 0.0
var grid_linear_size:int = 0
var grid_offset:float = 0.0
var placement_grid:Array = []
var diagonal_dilation:float = 1.0

var placement_overlaps:Array = []
var overlapped_octree_members:Array = []
var overdense_octree_members:Array = []

var raycast_positions:Array = []
var max_placements_allowed:int = 0

var jitter_fraction:float = 0.0

var logger = null




#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


func _init(__sphere_pos:Vector3, __sphere_radius:float, __plane_normal:Vector3, __jitter_fraction:float = 0.6):
	logger = Logger.get_for(self)
	sphere_pos = __sphere_pos
	sphere_radius = __sphere_radius
	sphere_diameter = sphere_radius * 2.0
	jitter_fraction = __jitter_fraction * 0.5
	init_axis_vectors(__plane_normal)


# Find two perpedicular vectors, so all 3 describe a plane/flat circle
func init_axis_vectors(source:Vector3):
	var nx := abs(source.x)
	var ny := abs(source.y)
	var nz := abs(source.z)
	var axis1:Vector3
	var axis2:Vector3
	
	if nz > nx && nz > ny:
		axis1 = Vector3(1,0,0)
	else:
		axis1 = Vector3(0,0,1)
	
	axis1 = (axis1 - source * axis1.dot(source)).normalized()
	axis2 = axis1.cross(source).normalized()
	plane_axis_vectors = [source, axis1, axis2]




#-------------------------------------------------------------------------------
# Grid data
#-------------------------------------------------------------------------------


# Initialize vital grid data
# Grid is used to maintain plant spacing defined by density
# Grid data helps to work with that spacing inside a given brush sphere
func init_grid_data(plant_density:float, brush_strength:float):
	point_distance = get_point_distance(plant_density, brush_strength)
	
	# Find how many linear segments fit within a diameter
	if point_distance > 0.0:
		grid_linear_size = floor(sphere_diameter / point_distance)
		
		# Then offset grid_linear_size by half a segment if it's an odd number
		if grid_linear_size % 2 == 0:
			grid_linear_size += 1
			point_distance *= (sphere_diameter / point_distance * 1) / (sphere_diameter / point_distance)
		
		# Subtract 1 because number of segments on a line is always 1 less than the number of points
		# Get max length all points occupy and take half of it
		grid_offset = (grid_linear_size - 1) * point_distance * -0.5
	else:
		grid_linear_size = 0
		grid_offset = 0.0
	
	init_placement_grid()
	debug_visualize_placement_grid("Grid initialized:")
	debug_log_grid("point_distance: %f, grid_linear_size: %d, grid_offset: %f" % [point_distance, grid_linear_size, grid_offset])


# Initialize the grid itself excluding points outside the sphere/plane circle
func init_placement_grid():
	placement_grid = []
	var radius_squared = pow(sphere_radius, 2)
	
	for x in range(0, grid_linear_size):
		placement_grid.append([])
		placement_grid[x].resize(grid_linear_size)
		for y in range(0, grid_linear_size):
			var local_pos = grid_coord_to_local_pos(Vector2(x, y))
			var dist = local_pos.length_squared()
			
			if dist <= radius_squared:
				placement_grid[x][y] = true
				max_placements_allowed += 1
			else:
				placement_grid[x][y] = false




#-------------------------------------------------------------------------------
# Overlaps
#-------------------------------------------------------------------------------


# Initialize placements overlapping with the given sphere
# Resulting placements will be in range (-sphere_radius, sphere_radius)
# Edge extension is used to grad one more/one less loop of overlaps
	# Typically used to grab members that were displaced with jitter_fraction
	# And happen to be outside our sphere_radius, but still belong to overlapped grid cells
func init_placement_overlaps(octree_manager:MMIOctreeManager, edge_extension:int = 0):
	placement_overlaps = []
	overlapped_octree_members = []
	
	var max_dist = sphere_radius + point_distance * edge_extension
	get_overlap_members(octree_manager.root_octree_node, max_dist)


# Recursively calculate placement overlaps in an octree
func get_overlap_members(octree_node:MMIOctreeNode, max_dist:float):
	var max_bounds_to_center_dist = octree_node.max_bounds_to_center_dist
	var dist_node := clamp((octree_node.center_pos - sphere_pos).length() - max_bounds_to_center_dist - sphere_radius, 0.0, INF)
	if dist_node >= max_dist: return
	
	if !octree_node.is_leaf:
		for child_node in octree_node.child_nodes:
			get_overlap_members(child_node, max_dist)
	else:
		var max_dist_squared = pow(max_dist, 2.0)
		var node_address = octree_node.get_address()
		for member_index in range(0, octree_node.members.size()):
			var member = octree_node.members[member_index]
			var placement = member.placement - sphere_pos
			var dist_squared = placement.length_squared()
			if dist_squared <= max_dist_squared:
				placement_overlaps.append(placement)
				overlapped_octree_members.append({"node_address": node_address, "member_index": member_index})


# Get all overlaps that don't fit into the density grid
func get_members_for_deletion():
	if overdense_octree_members.size() <= 0: return []
	
	var members_for_deletion := []
	# Don't delete more than is exessive or actually overdense
	var deletion_count := min(overlapped_octree_members.size() - max_placements_allowed, overdense_octree_members.size())
	var deletion_increment := float(deletion_count) / float(overdense_octree_members.size())
	var deletion_progress := 0.0
	
	if deletion_increment <= 0: return []
	
#	# This part picks every [N]th member for deletion
#	# [N] is defined by deletion_increment and can be fractional
#	# E.g. we can delete an approximation of every 0.3th, 0.75th, etc. element
	for index in range(0, overdense_octree_members.size()):
		deletion_progress += deletion_increment
		if deletion_progress >= 1.0:
			deletion_progress -= 1.0
			members_for_deletion.append(overdense_octree_members[index])
	
	return members_for_deletion


# Mark grid coordinates as invalid if they are already occupied
# (if there is a plant origin near a grid point)
func invalidate_occupied_points():
	for placement_index in range(0, placement_overlaps.size()):
		var placement_overlap = placement_overlaps[placement_index]
		# Project a local-space overlap to our plane
		var projected_overlap = Vector2(plane_axis_vectors[1].dot(placement_overlap), plane_axis_vectors[2].dot(placement_overlap))
		var grid_coord = local_pos_to_grid_coord(projected_overlap)
		grid_coord = Vector2(clamp(grid_coord.x, 0.0, grid_linear_size - 1), clamp(grid_coord.y, 0.0, grid_linear_size - 1))
		
		if placement_grid.size() > 0 && placement_grid[grid_coord.x][grid_coord.y]:
			invalidate_self_or_neighbor(grid_coord)
		else:
			overdense_octree_members.append(overlapped_octree_members[placement_index])



func invalidate_self_or_neighbor(grid_coord:Vector2):
	if placement_grid[grid_coord.x][grid_coord.y]:
		placement_grid[grid_coord.x][grid_coord.y] = false
	
	# Because our grid depends on brush position, sometimes we have cells that appear unoccupied
	# (Due to placements being *slightly* outside the cell)
	# So we nudge our overlaps one cell in whatever direction
	
	# CURRENT VERSION DOESN'T SOLVE THE ISSUE
	# THIS NEEDS TO APPROXIMATE THE BEST FITTING CELL BY COMPARING DISTANCES
	# AND AT THIS POINT IT'S TOO MANY CALCULATIONS
	# SO WE SUSPEND THIS FOR NOW
	
#	else:
#		var new_grid_coord
#		var offset_lookup = [
#			Vector2(-1,-1), Vector2(0,-1), Vector2(1,-1),
#			Vector2(-1,0), Vector2(1,0),
#			Vector2(-1,1), Vector2(0,1), Vector2(1,1)]
#		for offset in offset_lookup:
#			new_grid_coord = grid_coord + offset
#			if placement_grid[new_grid_coord.x][new_grid_coord.y]:
#				placement_grid[new_grid_coord.x][new_grid_coord.y] = false
#				break




#-------------------------------------------------------------------------------
# Raycast setup
#-------------------------------------------------------------------------------


# Get raycast start and end positions that go through the whole sphere
# Rays will start and end at the opposite sphere borders
# And will have the same direction as the brush normal
func get_valid_raycast_positions() -> Array:
	invalidate_occupied_points()
	debug_visualize_placement_grid("Grid invalidated occupied points:")
	generate_raycast_positions()
	return raycast_positions


# Generate a randomized placement for each point on the grid
# And deproject it onto our brush sphere using the surface normal
func generate_raycast_positions():
	raycast_positions = []
	for x in range(0, grid_linear_size):
		for y in range(0, grid_linear_size):
			if !placement_grid[x][y]: continue
			var grid_coord := Vector2(x, y)
			var UV_jitter := Vector2(rand_range(-jitter_fraction, jitter_fraction), rand_range(-jitter_fraction, jitter_fraction))
			grid_coord += UV_jitter
			var centered_UV := grid_coord_to_centered_UV(grid_coord)
			
			# Compensating a floating point error by padding the value a bit
			if centered_UV.length_squared() > 0.999:
				centered_UV = centered_UV.clamped(0.999)
			
			var UV_distance_to_surface:Vector3 = sqrt(1.0 - (pow(centered_UV.x, 2) + pow(centered_UV.y, 2))) * plane_axis_vectors[0]
			var UV_point_on_plane:Vector3 = centered_UV.x * plane_axis_vectors[1] + centered_UV.y * plane_axis_vectors[2]
			var raycast_start:Vector3 = sphere_pos + sphere_radius * (UV_point_on_plane + UV_distance_to_surface)
			var raycast_end:Vector3 = sphere_pos + sphere_radius * (UV_point_on_plane - UV_distance_to_surface)
			raycast_positions.append([raycast_start, raycast_end])
	
	# This was made to make sure we don't go over a max instance limit
	# I refactored placement logic to snap brush_pos to a density grid
	# Yet it doesn't 100% work on angled surfaces
	# We still might go over max placements, hence the limit check below
	# The percieved visual density should be unaffected though, especially at high (>= 0.5) jitter
	while raycast_positions.size() + placement_overlaps.size() > max_placements_allowed && !raycast_positions.empty():
		raycast_positions.remove(randi() % raycast_positions.size())




#-------------------------------------------------------------------------------
# Utility
#-------------------------------------------------------------------------------


# Get a linear distance between two points
# Separated into a function because we need this in StrokeHandler as well
static func get_point_distance(plant_density, brush_strength) -> float:
	# Convert square density to linear density
	# Then density per PLANT_DENSITY_UNITS to density per 1 unit
	# That is a distance between two points
	if brush_strength <= 0.0:
		return 0.0
	return (Globals.PLANT_DENSITY_UNITS / sqrt(plant_density * brush_strength))


# Convert grid coordinates to local position around the sphere center
# Resulting vector will be in range (-sphere_radius, sphere_radius)
func grid_coord_to_local_pos(grid_coord:Vector2) -> Vector2:
	return Vector2(
		grid_coord.x * point_distance + grid_offset,
		grid_coord.y * point_distance + grid_offset
	)


# Convert local position to grid coordinates
# Resulting vector will try to fit in range (0, grid_linear_size)
# (indexes might be outside the grid if positions lie outside, so the result usually should be clamped or rejected manually)
func local_pos_to_grid_coord(local_pos:Vector2) -> Vector2:
	if point_distance <= 0.0:
		return Vector2.ZERO
	
	return Vector2(
		round((local_pos.x - grid_offset) / point_distance),
		round((local_pos.y - grid_offset) / point_distance)
	)


# Convert grid coordinates to UV space in range (-1.0, 1.0)
func grid_coord_to_centered_UV(grid_coord:Vector2) -> Vector2:
	var local_pos = grid_coord_to_local_pos(grid_coord)
	return local_pos / sphere_radius




#-------------------------------------------------------------------------------
# Debug
#-------------------------------------------------------------------------------


# Print a nicely formatted placement grid to console
func debug_visualize_placement_grid(prefix:String = ""):
	if !FunLib.get_setting_safe("dreadpons_spatial_gardener/debug/brush_placement_area_log_grid", false): return
	
	if prefix != "":
		logger.info(prefix)
	if placement_grid.size() > 0:
		for y in range(0, placement_grid[0].size()):
			var string = "|"
			for x in range(0, placement_grid.size()):
				if placement_grid[x][y]:
					string += " "
				else:
					string += "X"
				if x < placement_grid[x].size() - 1:
					string += "|"
			string += "|"
			logger.info(string)
	print("\n")


func debug_log_grid(string:String):
	if !FunLib.get_setting_safe("dreadpons_spatial_gardener/debug/brush_placement_area_log_grid", false): return
	logger.info(string)
