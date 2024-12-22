class_name IslandH#elper

static func num_cells() -> Vector2i:
	return Vector2i((Settings.island_water_level_distance().get_size() - Vector2.ONE) / 2.0)

static func global_to_cell(pos: Vector2) -> Vector2:
	return (pos / Settings.terrain_cell_side() * Vector2(1, -1) + Vector2(num_cells()) / 2.0)

static func cell_to_global(cell: Vector2) -> Vector2:
	return (cell - Vector2(num_cells()) / 2.0) * Vector2(1, -1) * Settings.terrain_cell_side()

static func hit_pos_at_global(pos: Vector2) -> Vector3:
	return Vector3(pos.x, height_at_global(pos), pos.y)

static func height_at_global(pos: Vector2) -> float:
	return height_at_cell(global_to_cell(pos))

static func hit_pos_at_cell(pos: Vector2) -> Vector3:
	var global := cell_to_global(pos)
	return Vector3(global.x, height_at_cell(pos), global.y)

static func height_at_cell(cell: Vector2) -> float:
	var hm_img := Settings.island_heightmap_image()
	var lod := Vector2(hm_img.get_size() - Vector2i.ONE) / Vector2(Vector2i(Settings.island_water_level_distance().get_size() / 2))
	if lod != Vector2(Vector2i(lod)):
		SLog.se("Broken LOD for measuring heights (" + str(lod) + " != " + str(Vector2(Vector2i(lod))) + ")")
	var sample_from := cell * lod # It's a float to be interpolated!
	sample_from.y = hm_img.get_height() - 1 - sample_from.y
	if sample_from.x < 0 or sample_from.y < 0 or \
	sample_from.x >= hm_img.get_width() or sample_from.y >= hm_img.get_height():
		SLog.se("Tried to sample terrain height out of bounds, returning 0. Sample at: " + str(sample_from))
		return 0.0;
	var steps_from_bottom := Settings.island_water_level_at() / Settings.island_water_level_step()
	var steps_to_top := (1.0 - Settings.island_water_level_at()) / Settings.island_water_level_step()
	var minh = -Settings.terrain_max_steepness() / 2.0 * Settings.terrain_cell_side() * steps_from_bottom
	var maxh = Settings.terrain_max_steepness() / 2.0 * Settings.terrain_cell_side() * steps_to_top
	var res := HeightMap.read_height_interpolated(hm_img, sample_from.x, sample_from.y, minh, maxh)
	return res
