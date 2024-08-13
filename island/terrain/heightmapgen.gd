@tool
class_name HeightMapGen
extends SubViewport

func _init():
	self.set_update_mode(SubViewport.UPDATE_DISABLED)

func generate_heightmap(island: Island, mseed: int, target_vertices: int = Settings.terrain_vertex_count()) -> Array:
	# Create the max heights texture for the shader
	var height_bounds: Array = island.distance_to_water_level()
	var min_height: int      = height_bounds.map(func(x): return x.min()).min()
	var max_height: int      = height_bounds.map(func(x): return x.max()).max()
	var water_level_at: float = (0.0 - min_height) / (max_height - min_height);
	#print("MAX HEIGHTS:\n" + GameState.array_2d_to_ascii_string(
		#height_bounds.map(func(r): return r.map(func(x): return str(x)))))
	var texture_data: Array = []
	for x in range(height_bounds.size()): # Equal sizes
		for z in range(height_bounds[x].size()):
			texture_data.append((height_bounds[x][z] - min_height) * 255.99999 / (max_height - min_height))
	var height_bounds_img: Image = Image.create_from_data(height_bounds[0].size(), height_bounds.size(), false,
	Image.FORMAT_L8, texture_data)
	# max_heights_img.save_png("res://island/terrain/max_heights.png")  # Debug
	var height_bounds_tex: ImageTexture = ImageTexture.create_from_image(height_bounds_img)
	
	# Figure out the number of pixels to generate based on the target vertices
	var gen_ratio_xz: float = float(height_bounds[0].size()) / float(height_bounds.size())
	var gen_width: int      = int(sqrt(target_vertices) * gen_ratio_xz)
	var gen_height: int     = int(sqrt(target_vertices) / gen_ratio_xz)

	# Use the shader to render the high-res heightmap to another texture
	size = Vector2(gen_width, gen_height)
	var mat: Material = $Heightmap.material
	var noise: NoiseTexture2D = mat.get_shader_parameter("noise")
	noise.width = gen_width
	noise.height = gen_height
	noise.noise.seed = mseed
	mat.set_shader_parameter("distance_to_water_level", height_bounds_tex)
	mat.set_shader_parameter("water_level_at", water_level_at)
	self.set_update_mode(SubViewport.UPDATE_ONCE) # Render once!
	await RenderingServer.frame_pre_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_texture().get_image()
	img.save_png("res://island/terrain/heightmap.png")
	self.set_update_mode(SubViewport.UPDATE_DISABLED)
	
	# Decode the resulting image into the heightmap, applying max height bounds
	var heightmap: Array = []
	for z in range(gen_height):
		var row: Array = []
		for x in range(gen_width):
			var height: float = img.get_pixel(x, z).r
			row.append(height * (max_height - min_height) + min_height)
		heightmap.append(row)

	return [heightmap, Vector2(gen_width, gen_height)]
