extends Node3D

func _on_water_built(size: Vector2) -> void:
	# Now trigger the placement of props in the ocean (not colliding with terrain)
	var area := Vector3(1.2 * size.x, 0.1, 1.2 * size.y)
	($ProtonScatter/ForbiddenBox.shape as ProtonScatterBoxShape).size = area
	($ProtonScatter/AllowedBox.shape as ProtonScatterBoxShape).size =  Vector3(area.x * 2.0, 0.1, area.z * 2.0)
	$ProtonScatter.global_seed = Settings.common_seed()
	var create = $ProtonScatter.modifier_stack.stack[0]
	create.amount = int(5.0 * Settings.common_props_multiplier())
	$ProtonScatter.enabled = true
