@tool
extends Node3D

@onready var _scatterers_meta: Array[Dictionary] = [
	{"scatterer": $Trees, "per_cell": 4.0, "biome_noise_freq": 0.05, "biome_noise_strength01": 0.1, "biome_mod": func(height01, hit):
		return 1.0 - abs(0.5 - height01) / 1.0 + (hit.normal.y - 0.9) / 0.1 if height01 >= 0.1 else 0.0},
	{"scatterer": $Rocks, "per_cell": 1.0, "biome_noise_freq": 0.2, "biome_noise_strength01": 0.1, "biome_mod": func(height01, _hit):
		return max((height01 - 0.6) / 0.1, 1.0 - abs(0.1 - height01) / 0.4)},
	{"scatterer": $Grass, "per_cell": 8.0, "biome_noise_freq": 0.03, "biome_noise_strength01": 0.9, "biome_mod": func(height01, _hit):
		return 1.0 if height01 >= 0.0 else 0.0},
	{"scatterer": $Bushes, "per_cell": 3.0, "biome_noise_freq": 0.1, "biome_noise_strength01": 0.5, "biome_mod": func(height01, _hit):
		return 1.0 if height01 >= 0.1 else 0.0},
	{"scatterer": $DeadBranches, "per_cell": 3.0, "biome_noise_freq": 0.05, "biome_noise_strength01": 0.5, "biome_mod": func(height01, _hit):
		return max(0.0, 1.0 - abs(0.4 - height01) / 0.6)},
]

func _on_terrain_terrain_ready(mi: MeshInstance3D, _game: GameState) -> void:
	if Engine.is_editor_hint():
		return # Avoid making persistent edits in the editor (remove this for testing)
	
	#Common
	IslandH.ensure_terrain_collision(mi)
	var mseed := Settings.common_seed()
	var aabb = mi.get_aabb()
	var num_cells: Vector2i = Vector2i((Settings.island_water_level_distance().get_size() - Vector2.ONE) / 2.0)
	var props_mult := Settings.common_props_multiplier()
	if props_mult < 1.0:
		props_mult = pow(props_mult, 4.0)  # More intense reduction

	#Handle all scatterers similarly, but with some customization
	for scatterer_meta_i in range(_scatterers_meta.size()):
		var start_time := Time.get_ticks_msec()
		var scatterer_meta = _scatterers_meta[scatterer_meta_i]
		var scatterer: Node3D = scatterer_meta["scatterer"]
		var per_cell: float = scatterer_meta["per_cell"]
		var biome_noise_freq: float = scatterer_meta["biome_noise_freq"]
		var biome_noise_strength01: float = scatterer_meta["biome_noise_strength01"]
		var biome_modifier: Callable = scatterer_meta["biome_mod"]
		scatterer.global_seed = mseed + scatterer_meta_i

		# Adjust shape to drop only above island area
		scatterer.get_children().map(func(shape: Node3D):
			if shape.name == "ScatterShape":  # TODO: Better detection
				shape.position = Vector3(aabb.get_center().x, aabb.end.y, aabb.get_center().z)
				shape.shape.size = aabb.size)

		# Set the amount according to the per_cell modifier
		scatterer.modifier_stack.stack[0].amount = int(per_cell * num_cells.x * num_cells.y * props_mult)

		# Build biomes
		# - Create noise for more natural looking results
		var biome_texture := NoiseTexture2D.new()
		biome_texture.width = num_cells.x
		biome_texture.height = num_cells.y
		var biome_texture_gen := FastNoiseLite.new()
		biome_texture_gen.seed = scatterer.global_seed
		biome_texture_gen.frequency = biome_noise_freq
		biome_texture.noise = biome_texture_gen
		await biome_texture.changed
		# - Adjust the texture with our modifier
		var biome_img: Image = biome_texture.get_image()
		for y in range(num_cells.y):
			for x in range(num_cells.x):
				var hit = IslandH.query_terrain(mi, Vector2(x, y) + Vector2.ONE)
				#print("XY cell: " + str(Vector2(x,y)) + ", hit: " + str(hit.position))
				if not hit:
					SLog.se("Didn't hit the terrain?!")
					continue
				var height01 = (hit.position.y - aabb.position.y) / aabb.size.y
				var height01abovewater = (height01 - Settings.island_water_level_at()) / (1.0 - Settings.island_water_level_at())
				var natural = clamp(biome_modifier.call(height01abovewater, hit), 0.0, 1.0) # Height can be negative for underwater, otherwise in [0, 1]
				var noise = biome_img.get_pixel(x, y).r  # Apply previous noise!
				var cell_likelyhood = noise * biome_noise_strength01 + natural * (1.0 - biome_noise_strength01)
				biome_img.set_pixel(x, y, cell_likelyhood * Color.WHITE)
				#print("X: " + str(x) + ", Y: " + str(y) + " > HIT: " + str(hit.position) + " | H: " + str(height01) + ", H2: " + str(height01abovewater) + ", M: " + str(mult) + " | C: " + str(biome_img.get_pixel(x, y)))
		# - Set the noise as the clusterize parameter
		var clusterize_index = 2
		var clusterize = scatterer.modifier_stack.stack[clusterize_index]
		clusterize.pixel_to_unit_ratio = 1.0 # / Settings.terrain_cell_side()
		clusterize.mask_scale = Vector2.ONE * Settings.terrain_cell_side()
		clusterize.mask_offset = -Vector2(num_cells) / 2.0
		clusterize.mask_texture = ImageTexture.create_from_image(biome_img)
		#biome_img.save_png("/home/yeicor/test.png")

		SLog.sd("[timing] " + scatterer.name + " setup completed after " + str(Time.get_ticks_msec() - start_time) + "ms (will build " + str(scatterer.modifier_stack.stack[0].amount) + " elements)")
		scatterer.chunk_dimensions = Vector3.ONE * 20.0 * aabb.size / Vector3(num_cells.x, 1, num_cells.y)
		start_time = Time.get_ticks_msec()
		scatterer.connect("build_completed", func():
			SLog.sd("[timing] " + scatterer.name + " background build completed after " + str(Time.get_ticks_msec() - start_time) + " ms"), CONNECT_ONE_SHOT)
		scatterer.enabled = true
