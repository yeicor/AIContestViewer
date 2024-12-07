@tool
extends Node3D
class_name Lighthouses

static func ensure_terrain_collision(mi: MeshInstance3D) -> void:
	var start_time = Time.get_ticks_msec()
	# Create collision shape for terrain only if needed
	@warning_ignore("standalone_expression")
	if not mi.get_children().any(func(c): c is PhysicsBody3D):
		mi.create_trimesh_collision()
		SLog.sd("[timing] Created collision for terrain in " + str(Time.get_ticks_msec() - start_time) + "ms")

static func global_to_cell(pos: Vector2) -> Vector2: # TODO: Find a better place for these functions (Settings?)
	var num_cells = Vector2i((Settings.island_water_level_distance().get_size() - Vector2.ONE) / 2.0)
	return pos / Settings.terrain_cell_side() - Vector2(num_cells) / 2.0

static func cell_to_global(cell: Vector2) -> Vector2:
	var num_cells = Vector2i((Settings.island_water_level_distance().get_size() - Vector2.ONE) / 2.0)
	return (cell - Vector2(num_cells) / 2.0) * Settings.terrain_cell_side()

static func query_terrain(mi: MeshInstance3D, cell_xz: Vector2) -> Dictionary:
	var aabb = mi.get_aabb()
	var lh_wl_image := Settings.island_water_level_distance_image()
	@warning_ignore("integer_division")
	var cell_count = Vector2i((lh_wl_image.get_width()-1)/2, (lh_wl_image.get_height()-1)/2)
	var p_rel = Vector3(cell_xz.x / float(cell_count.x), aabb.end.y + 1, cell_xz.y / float(cell_count.y))
	var p = aabb.position + aabb.size * p_rel
	return mi.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p, Vector3(p.x, aabb.position.y, p.z)))

func _on_terrain_terrain_ready(mi: MeshInstance3D, _game: GameState) -> void:
	ensure_terrain_collision(mi)
	var start_time := Time.get_ticks_msec()
	# Clear previous lighthouses
	get_children().map(func(c): c.queue_free())
	# Spawn the lighthouses at the appropriate locations...
	var lh := preload("res://island/lighthouse/lighthouse.tscn")
	var lh_wl_image := Settings.island_water_level_distance_image()
	for y in range(lh_wl_image.get_height()):
		for x in range(lh_wl_image.get_width()):
			if lh_wl_image.get_pixel(x, y).g == 1.0:
				var hit = query_terrain(mi, Vector2(x / 2.0, y / 2.0))
				if hit:
					var child = lh.instantiate()
					# TODO: child.name (with original IDs, taken from the array...!)
					child.position = hit.position
					child.rotate_y(randf() * 2 * PI)
					child.color = Color(randf(), randf(), randf())
					add_child(child)
				else:
					SLog.sd("ERROR: Couldn't hit raycast to place lighthouse!!!")
	SLog.sd("[timing] Placed lighthouses in " + str(Time.get_ticks_msec() - start_time) + "ms")
