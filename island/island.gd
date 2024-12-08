class_name IslandH#elper

static func ensure_terrain_collision(mi: MeshInstance3D) -> void:
	var start_time = Time.get_ticks_msec()
	# Create collision shape for terrain only if needed
	@warning_ignore("standalone_expression")
	if not mi.get_children().any(func(c): c is PhysicsBody3D):
		mi.create_trimesh_collision()
		SLog.sd("[timing] Created collision for terrain in " + str(Time.get_ticks_msec() - start_time) + "ms")

static func num_cells() -> Vector2i:
	return Vector2i((Settings.island_water_level_distance().get_size() - Vector2.ONE) / 2.0)

static func global_to_cell(pos: Vector2) -> Vector2:
	return (pos / Settings.terrain_cell_side() * Vector2(1, -1) + Vector2(num_cells()) / 2.0)

static func cell_to_global(cell_i: Vector2) -> Vector2:
	return (cell_i - Vector2(num_cells()) / 2.0) * Vector2(1, -1) * Settings.terrain_cell_side()

static func query_terrain(mi: MeshInstance3D, global_xz: Vector2) -> Dictionary:
	var aabb = mi.get_aabb()
	var p = Vector3(global_xz.x, aabb.end.y, global_xz.y)
	return mi.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(p, Vector3(p.x, aabb.position.y, p.z)))
