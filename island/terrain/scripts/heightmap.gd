@tool
class_name HeightMap
extends SubViewport

func _init():
	self.set_update_mode(SubViewport.UPDATE_DISABLED)


func generate(game: GameState, mseed: int, target_vertices: int = Setting.terrain_vertex_count()) -> Array:
	# Create the max heights texture for the shader
	var height_bounds: Array  = game.island(false).distance_to_water_level()
	var start_time: float     = Time.get_ticks_msec()
	var min_height: float     = height_bounds.map(func(x): return x.min()).min()
	var max_height: float     = height_bounds.map(func(x): return x.max()).max()
	var water_level_at: float = (0.0 - min_height) / (max_height - min_height);
	var y_level_step := 1.0 / float(max_height - min_height)
	#print("MAX HEIGHTS:\n" + GameState.array_2d_to_ascii_string(
	#height_bounds.map(func(r): return r.map(func(x): return str(x)))))
	var texture_data: Array = []
	var lh_positions: Array = game.lighthouses().map(func(lh): return lh.pos())
	for x in range(height_bounds.size()): # Equal sizes
		for z in range(height_bounds[x].size()):
			# Red channel: distance to water level
			texture_data.append((height_bounds[x][z] - min_height) * 255.99999 / (max_height - min_height))
			# Blue channel: lighthouse presence
			if Vector2i(x, z) in lh_positions:
				texture_data.append(255)
			else:
				texture_data.append(0)
	var height_bounds_img: Image = Image.create_from_data(height_bounds[0].size(), height_bounds.size(), false,
	Image.FORMAT_RG8, texture_data)
	#height_bounds_img.save_png("res://island/terrain/scripts/max_heights.png")  # Debug
	var height_bounds_tex: ImageTexture = ImageTexture.create_from_image(height_bounds_img)
	print("[timing] HeightmapGen: Created max heights texture in " + str(Time.get_ticks_msec() - start_time) + "ms  (excluding distance to water level)")

	# Figure out the number of pixels to generate based on the target vertices
	var gen_ratio_xz: float = float(height_bounds[0].size()) / float(height_bounds.size())
	var gen_width: int  = int(sqrt(target_vertices) * gen_ratio_xz)
	var gen_height: int = int(sqrt(target_vertices) / gen_ratio_xz)

	# Use the shader to render the high-res heightmap to another texture
	start_time = Time.get_ticks_msec()
	size = Vector2(gen_width, gen_height)
	var mat: Material = $HeightMap.material
	mat.set_shader_parameter("my_seed", mseed)
	mat.set_shader_parameter("distance_to_water_level", height_bounds_tex)
	mat.set_shader_parameter("water_level_at", water_level_at)
	mat.set_shader_parameter("y_level_step", y_level_step)
	self.set_update_mode(SubViewport.UPDATE_ONCE) # Render once!
	await RenderingServer.frame_post_draw
	var img: Image = get_texture().get_image()
	#img.save_png("res://island/terrain/scripts/heightmap.png")
	self.set_update_mode(SubViewport.UPDATE_DISABLED)
	print("[timing] HeightmapGen: GPU-generated " + str(size) + " heightmap in " + str(Time.get_ticks_msec() - start_time) + "ms")

	# Decode the resulting image into the heightmap, applying max height bounds
	start_time = Time.get_ticks_msec()
	var heightmap: Array = []
	for z in range(gen_height):
		var row: Array = []
		for x in range(gen_width):
			var color: Color = img.get_pixel(x, z)
			# Need to unpack the height that was split along 4 components for maximum precision!
			const precision: float = 256.0
			var height: float      = color.r + color.g / precision
			row.append(height * (max_height - min_height) + min_height)
		heightmap.append(row)
	print("[timing] HeightmapGen: CPU-decoded " + str(size) + " heightmap in " + str(Time.get_ticks_msec() - start_time) + "ms")

	return [heightmap, Vector2(gen_width, gen_height)]
