@tool
extends Node3D

@onready var _scatterers_meta: Array[Dictionary] = [
	{"scatterer": $Trees, "per_cell": 4.0, "biome_noise_freq": 0.05, "biome_noise_strength01": 0.1, "biome_mod": func(height01, normal):
		return (1.0 - abs(0.5 - height01) / 1.0 + (normal.y - 0.7) / 0.3) if height01 >= 0.15 else 0.0},
	{"scatterer": $DeadBranches, "per_cell": 3.0, "biome_noise_freq": 0.05, "biome_noise_strength01": 0.5, "biome_mod": func(height01, normal):
		return max(0.1, (1.0 - abs(0.5 - height01) / 1.0 + (normal.y - 0.7) / 0.3) if height01 >= 0.15 else 0.0)},
	{"scatterer": $Rocks, "per_cell": 1.0, "biome_noise_freq": 0.2, "biome_noise_strength01": 0.1, "biome_mod": func(height01, _normal):
		return max((height01 - 0.6) / 0.1, 1.0 - abs(0.1 - height01) / 0.4)},
	{"scatterer": $Grass, "per_cell": 8.0, "biome_noise_freq": 0.03, "biome_noise_strength01": 0.9, "biome_mod": func(height01, _normal):
		return 1.0 if height01 >= 0.0 else 0.0},
	{"scatterer": $Bushes, "per_cell": 3.0, "biome_noise_freq": 0.1, "biome_noise_strength01": 0.5, "biome_mod": func(height01, _normal):
		return 1.0 if height01 >= 0.1 else 0.0},
]

func _on_terrain_terrain_ready(mi: MeshInstance3D, _game: GameState, cached: bool) -> void:
	if cached: return
	if Settings.common_props_multiplier() <= 0.0:
		SLog.sd("Props disabled, skipping scatterer configuration...")
		return
	GameManager.pause() # Lock the game timer while generating
	#Common
	var mseed := Settings.common_seed()
	var aabb = mi.get_aabb()
	var num_cells: Vector2i = Vector2i((Settings.island_water_level_distance().get_size() - Vector2.ONE) / 2.0)
	var props_mult := Settings.common_props_multiplier()
	if props_mult < 1.0:
		props_mult = pow(props_mult, 4.0)  # More intense reduction

	# Collision
	add_collision_shape(mi, num_cells * 3 * int(props_mult), num_cells)
	
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
		
		# Clear previous props and force update
		scatterer.enabled = false

		# Adjust shape to drop only above island area
		scatterer.get_children().map(func(shape: Node3D):
			if shape.name == "ScatterShape":  # TODO: Better detection
				shape.position = Vector3(aabb.get_center().x, aabb.end.y, aabb.get_center().z)
				shape.shape.size = aabb.size)

		# Set the amount according to the per_cell modifier
		scatterer.modifier_stack.stack[0].amount = int(per_cell * num_cells.x * num_cells.y * props_mult)

		# Build biomes
		# - Create noise for more natural looking results
		var supersampling := 1 # Requires fixes if != 1
		var biome_texture := NoiseTexture2D.new()
		biome_texture.width = num_cells.x * supersampling
		biome_texture.height = num_cells.y * supersampling
		var biome_texture_gen := FastNoiseLite.new()
		biome_texture_gen.seed = scatterer.global_seed
		biome_texture_gen.frequency = biome_noise_freq
		biome_texture.noise = biome_texture_gen
		await biome_texture.changed
		# - Adjust the texture with our modifier
		var biome_img: Image = biome_texture.get_image()
		for yi in range(num_cells.y * supersampling): # Approximation over each cell instead of accessing all heightmap data for performance reasons :/
			var y = float(yi) / float(supersampling) + 1.0 / float(supersampling + 1) # [0.25, 0.75] instead of [0, 0.5]
			for xi in range(num_cells.x * supersampling):
				var x = float(xi) / float(supersampling) + 1.0 / float(supersampling + 1)
				var sample_center_cell := Vector2(x, y)
				var hit_height = IslandH.height_at_cell(sample_center_cell)
				var normal = (Vector3( # BAD approximation
					IslandH.height_at_cell(sample_center_cell + Vector2(0.1, 0.0)) - hit_height,
					0.4, IslandH.height_at_cell(sample_center_cell + Vector2(0.0, 0.1)) - hit_height,
				)).normalized()
				#print("XY cell: " + str(Vector2(x,y)) + ", hit_height: " + str(hit_height) + ", normal: " + str(normal))
				var height01abovewater = hit_height / aabb.end.y
				var natural = clamp(biome_modifier.call(height01abovewater, normal), 0.0, 1.0) # Height can be negative for underwater, otherwise in [0, 1]
				var noise = biome_img.get_pixel(x, y).r  # Apply previous noise!
				var cell_likelyhood = natural * (1.0 - biome_noise_strength01)
				if natural < 0.001: # Ignore noise if natural is 0.0
					cell_likelyhood += noise * biome_noise_strength01
				biome_img.set_pixel(xi, biome_texture.height - 1 - yi, cell_likelyhood * Color.WHITE)
				#print("X: " + str(x) + ", Y: " + str(y) + " > HIT: " + str(hit.position) + " | H: " + str(height01) + ", H2: " + str(height01abovewater) + ", M: " + str(mult) + " | C: " + str(biome_img.get_pixel(x, y)))
		# - Set the noise as the clusterize parameter
		var clusterize_index = 2
		var clusterize = scatterer.modifier_stack.stack[clusterize_index]
		clusterize.pixel_to_unit_ratio = 1.0 # / Settings.terrain_cell_side()
		clusterize.mask_scale = Vector2.ONE * Settings.terrain_cell_side()
		clusterize.mask_offset = -Vector2(num_cells) / 2.0
		clusterize.mask_texture = ImageTexture.create_from_image(biome_img)
		#biome_img.save_png(OS.get_environment("HOME") + "/biome_"+scatterer.name+".png")

		SLog.sd("[timing] " + scatterer.name + " setup completed after " + str(Time.get_ticks_msec() - start_time) + "ms (will build " + str(scatterer.modifier_stack.stack[0].amount) + " elements)")
		scatterer.chunk_dimensions = Vector3.ONE * 20.0 * aabb.size / Vector3(num_cells.x, 1, num_cells.y)
		start_time = Time.get_ticks_msec()
		GameManager.pause() # Lock the game timer while generating
		scatterer.connect("build_completed", func():
			SLog.sd("[timing] " + scatterer.name + " background build completed after " + str(Time.get_ticks_msec() - start_time) + " ms")
			GameManager.resume(), CONNECT_ONE_SHOT)
		scatterer.enabled = true
	
	GameManager.resume() # See also callback pause and resumes!


func add_collision_shape(terrain: MeshInstance3D, num_samples: Vector2i, num_cells: Vector2i):
	# Simplified heightmap collision
	var start_time_collision := Time.get_ticks_msec()
	var hm := HeightMapShape3D.new()
	hm.map_width = num_cells.x
	hm.map_depth = num_cells.y
	if (float(num_samples.x) / float(num_cells.x) != float(num_samples.y) / float(num_cells.y)):
		SLog.se("Heightmap collision shape requires uniform scaling, please fix your number of samples")
	var uniform_scale := float(num_cells.x) / float(num_samples.x) * Settings.terrain_cell_side()

	# Populate the heightmap
	var map_data = Image.create_empty(num_samples.x, num_samples.y, false, Image.FORMAT_RF)
	var aabb = terrain.get_aabb()
	var min_height01 = 1.0
	var max_height01 = 0.0
	for yi in range(num_samples.y):
		for xi in range(num_samples.x):
			var cell_position := Vector2(
				float(xi) / num_samples.x * num_cells.x,
				float(yi) / num_samples.y * num_cells.y)
			var height = IslandH.height_at_cell(cell_position)
			var height01 = clamp((height - aabb.position.y) / aabb.size.y, 0.0, 1.0)
			if height01 < min_height01: min_height01 = height01
			if height01 > max_height01: max_height01 = height01
			map_data.set_pixel(xi, num_samples.y - 1 - yi, Color.WHITE * height01)
	hm.update_map_data_from_image(map_data, 
		(aabb.position.y + aabb.size.y * min_height01) / uniform_scale, 
		(aabb.end.y - + aabb.size.y * (1.0 - max_height01)) / uniform_scale)

	# Create the collision object
	var collision_body := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = hm
	collision_shape.scale = Vector3.ONE * uniform_scale # required to be uniform!
	collision_body.add_child(collision_shape)
	terrain.add_child(collision_body)

	# Debugging
	#var debug_mi := MeshInstance3D.new()
	#debug_mi.mesh = hm.get_debug_mesh()
	#debug_mi.scale = collision_shape.scale
	#terrain.add_child(debug_mi)

	SLog.sd("[timing] Created terrain heightmap collision in " + str(Time.get_ticks_msec() - start_time_collision) + " ms")
