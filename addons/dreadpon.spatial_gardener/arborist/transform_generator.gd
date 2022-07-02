tool


#-------------------------------------------------------------------------------
# A function library for generating individual plant tranforms
# Based on the given placement position and Greenhouse_Plant settings
#-------------------------------------------------------------------------------


const FunLib = preload("../utility/fun_lib.gd")
const Greenhouse_Plant = preload("../greenhouse/greenhouse_plant.gd")




# Randomize an instance transform according to its Greenhouse_Plant settings
static func generate_plant_transform(placement, normal, plant, randomizer) -> Transform:
	var up_vector_primary:Vector3 = get_dir_vector(plant.up_vector_primary_type, plant.up_vector_primary, normal)
	var up_vector_secondary:Vector3 = get_dir_vector(plant.up_vector_secondary_type, plant.up_vector_secondary, normal)
	var plant_up_vector:Vector3 = lerp(up_vector_primary, up_vector_secondary, plant.up_vector_blending).normalized()
	
	var fwd_vector_primary:Vector3 = get_dir_vector(plant.fwd_vector_primary_type, plant.fwd_vector_primary, normal)
	var fwd_vector_secondary:Vector3 = get_dir_vector(plant.fwd_vector_secondary_type, plant.fwd_vector_secondary, normal)
	var plant_fwd_vector:Vector3 = lerp(fwd_vector_primary, fwd_vector_secondary, plant.fwd_vector_blending).normalized()
	
	var plant_scale:Vector3 = FunLib.vector_tri_lerp(
		plant.scale_range[0],
		plant.scale_range[1],
		get_scaling_randomized_weight(plant.scale_scaling_type, randomizer)
	)
	
	var plant_y_offset = lerp(plant.offset_y_range[0], plant.offset_y_range[1], randomizer.randf_range(0.0, 1.0)) * plant_scale
	
	var plant_rotation = Vector3(
		deg2rad(lerp(-plant.rotation_random_x, plant.rotation_random_x, randomizer.randf_range(0.0, 1.0))),
		deg2rad(lerp(-plant.rotation_random_y, plant.rotation_random_y, randomizer.randf_range(0.0, 1.0))),
		deg2rad(lerp(-plant.rotation_random_z, plant.rotation_random_z, randomizer.randf_range(0.0, 1.0)))
	)
	
	var plant_basis:Basis = Basis()
	plant_basis.y = plant_up_vector
	
	# If one of the forward vectors is unused and contributes to a blend
	if ((plant.fwd_vector_primary_type == Greenhouse_Plant.DirectionVectorType.UNUSED && plant.fwd_vector_blending != 1.0)
		|| (plant.fwd_vector_secondary_type == Greenhouse_Plant.DirectionVectorType.UNUSED && plant.fwd_vector_blending != 0.0)):
		# Use automatic forward vector
		plant_basis.z = Vector3.FORWARD.rotated(plant_up_vector, plant_rotation.y)
	else:
		plant_basis.z = plant_fwd_vector.rotated(plant_up_vector, plant_rotation.y)
	
	plant_basis.x = plant_basis.y.cross(plant_basis.z)
	plant_basis.z = plant_basis.x.cross(plant_basis.y)
	plant_basis = plant_basis.orthonormalized()
	plant_basis = plant_basis.rotated(plant_basis.x, plant_rotation.x)
	plant_basis = plant_basis.rotated(plant_basis.z, plant_rotation.z)
	
	plant_basis.x *= plant_scale.x
	plant_basis.y *= plant_scale.y
	plant_basis.z *= plant_scale.z
	
	var plant_origin = placement + plant_y_offset * plant_basis.y.normalized()
	var plant_transform = Transform(plant_basis, plant_origin)
	return plant_transform


# See slope_allowedRange in Greenhouse_Plant
static func is_plant_slope_allowed(normal, plant) -> bool:
	var up_vector_primary:Vector3 = get_dir_vector(plant.up_vector_primary_type, plant.up_vector_primary, normal)
	var slope_angle = abs(rad2deg(up_vector_primary.angle_to(normal)))
	return slope_angle >= plant.slope_allowed_range[0] && slope_angle <= plant.slope_allowed_range[1]


# Choose the appropriate direction vector
static func get_dir_vector(dir_vector_type, custom_vector:Vector3, normal:Vector3) -> Vector3:
	match dir_vector_type:
		Greenhouse_Plant.DirectionVectorType.WORLD_X:
			return Vector3.RIGHT
		Greenhouse_Plant.DirectionVectorType.WORLD_Y:
			return Vector3.UP
		Greenhouse_Plant.DirectionVectorType.WORLD_Z:
			return Vector3.FORWARD
		Greenhouse_Plant.DirectionVectorType.NORMAL:
			return normal
		Greenhouse_Plant.DirectionVectorType.CUSTOM:
			return custom_vector.normalized()
	return Vector3.UP


# Enforce the scaling plane lock if present
# The scaling itself is already enforced by Greenhouse_Plant
# But we need to enforce the randomization as well
static func get_scaling_randomized_weight(scaling_type, randomizer) -> Vector3:
	var scale_weight = Vector3()
	match scaling_type:
		Greenhouse_Plant.ScalingType.UNIFORM:
			scale_weight.x = randomizer.randf_range(0.0, 1.0)
			scale_weight.y = scale_weight.x
			scale_weight.z = scale_weight.x
		Greenhouse_Plant.ScalingType.FREE:
			scale_weight.x = randomizer.randf_range(0.0, 1.0)
			scale_weight.y = randomizer.randf_range(0.0, 1.0)
			scale_weight.z = randomizer.randf_range(0.0, 1.0)
		Greenhouse_Plant.ScalingType.LOCK_XY:
			scale_weight.x = randomizer.randf_range(0.0, 1.0)
			scale_weight.y = scale_weight.x
			scale_weight.z = randomizer.randf_range(0.0, 1.0)
		Greenhouse_Plant.ScalingType.LOCK_ZY:
			scale_weight.x = randomizer.randf_range(0.0, 1.0)
			scale_weight.y = randomizer.randf_range(0.0, 1.0)
			scale_weight.z = scale_weight.y
		Greenhouse_Plant.ScalingType.LOCK_XZ:
			scale_weight.x = randomizer.randf_range(0.0, 1.0)
			scale_weight.y = randomizer.randf_range(0.0, 1.0)
			scale_weight.z = scale_weight.x
	
	return scale_weight
