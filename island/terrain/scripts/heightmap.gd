@tool
class_name HeightMap
extends SubViewport

var _last_heightmap: Image  # Don't call too fast, not properly synchronized


func _init():
	self.set_update_mode(SubViewport.UPDATE_DISABLED)


func generate(game: GameState, mseed: int, cell_side: float, steepness: float, target_vertices: int) -> Mesh:
	# Create the max heights texture for the shader
	var island                := game.island(false)
	var height_bounds: Array  =  island.distance_cell_corners_to_water_level()
	var start_time: float     =  Time.get_ticks_msec()
	var min_height: float     =  height_bounds.map(func(x): return x.min()).min()
	var max_height: float     =  height_bounds.map(func(x): return x.max()).max()
	var water_level_at: float =  (0.0 - min_height) / (max_height - min_height);
	var y_level_step := 1.0 / (max_height - min_height)
	#print("MAX HEIGHTS:\n" + GameState.array_2d_to_ascii_string(
	#height_bounds.map(func(r): return r.map(func(x): return str(x)))))
	var texture_data: Array = []
	var lh_positions: Array = game.lighthouses().map(func(lh): 
		var scaled_pos = lh.pos() * 2 + Vector2i(1, 1)
		return Vector2i(scaled_pos.x, height_bounds.size() - 1 - scaled_pos.y))
	for z in range(height_bounds.size()): # Equal sizes
		for x in range(height_bounds[z].size()):
			# Red channel: distance to water level
			texture_data.append((height_bounds[z][x] - min_height) * 255.99999 / (max_height - min_height))
			# Blue channel: lighthouse presence (255) or nearby-ness (>0, <255, assuming search range <255)
			var search_range := 1 # This is enough, more would need a more complex heightmap shader
			var lh_closeness := 0.0
			for lh_pos in lh_positions:
				var this_lh_closeness = 1.0 - lh_pos.distance_to(Vector2(x, z)) / search_range
				lh_closeness = max(lh_closeness, this_lh_closeness) # Don't add, as 255 is reserved for presence.
			texture_data.append(lh_closeness * 255.99999)
	var height_bounds_img: Image = Image.create_from_data(height_bounds[0].size(), height_bounds.size(), false,
	Image.FORMAT_RG8, texture_data)
	#height_bounds_img.save_png("res://island/terrain/scripts/max_heights.png")  # Debug
	var height_bounds_tex: ImageTexture = ImageTexture.create_from_image(height_bounds_img)
	SLog.sd("[timing] HeightMap: Created max heights texture in " + str(Time.get_ticks_msec() - start_time) + "ms  (excluding distance to water level)")

	# Figure out the number of pixels to generate based on the target vertices
	var n              =  closest_N(island.width(), island.height(), target_vertices)
	if n < 1: n = 1 # At least 1 vertex per cell...
	var verts_per_side := Vector2(0, 0)
	verts_per_side.x = n * island.width() + 1
	verts_per_side.y = n * island.height() + 1

	# Use the shader to render the high-res heightmap to another texture ("blocking" the main thread!)
	var gpu_semaphore := Semaphore.new()
	_run_gpu.call_deferred(mseed, height_bounds_tex, water_level_at, y_level_step, gpu_semaphore, verts_per_side)

	# Mean-while, prepare the plane mesh in the CPU!
	start_time = Time.get_ticks_msec()
	var y_step     := steepness * cell_side / 2
	var plane_mesh =  PlaneMesh.new()
	plane_mesh.subdivide_width = verts_per_side.x - 2 # 0 subdivisions = 2 vertex per sides; and 1 adds 1.
	plane_mesh.subdivide_depth = verts_per_side.y - 2
	plane_mesh.size = cell_side * island.size()
	var st         := SurfaceTool.new()
	st.create_from(plane_mesh, 0)
	var mesh = st.commit()
	SLog.sd("[timing] Generated plane for heightmap of size " + str(verts_per_side) +
	" (n="+str(n)+") in " + str(Time.get_ticks_msec() - start_time) + "ms")

	start_time = Time.get_ticks_msec()
	var mdt   = MeshDataTool.new()
	var error = mdt.create_from_surface(mesh, 0)
	if error != OK:
		print("Error creating MeshDataTool from plane: " + str(error))
		return null
	SLog.sd("[timing] Created MeshDataTool from plane in " + str(Time.get_ticks_msec() - start_time) + "ms")

	# Ensure the GPU-generated heightmap is ready before proceeding to read it
	start_time = Time.get_ticks_msec()
	gpu_semaphore.wait()
	SLog.sd("[timing] CPU was waiting for GPU to generate heightmap for " + str(Time.get_ticks_msec() - start_time) + "ms")

	start_time = Time.get_ticks_msec()
	for z in range(0, verts_per_side.y):
		var z_row_base_id := z * verts_per_side.x
		for x in range(0, verts_per_side.x):
			var v_id = z_row_base_id + x;
			var vertex_pos = mdt.get_vertex(v_id);
			var v_x =  -vertex_pos.x # SWAP x
			var v_z =  -vertex_pos.z # SWAP y
			var v_y := _read_height(x, z, min_height, max_height) * y_step
			var vn_off_x: float
			if x + 1 < verts_per_side.x and x - 1 >= 0:
				vn_off_x = _read_height(x + 1, z, min_height, max_height) * y_step - _read_height(x - 1, z, min_height, max_height) * y_step
			else:
				vn_off_x = 0 # For x_inf and boundaries
			var vn_off_z: float
			if z + 1 < verts_per_side.y and z - 1 >= 0:
				vn_off_z = _read_height(x, z + 1, min_height, max_height) * y_step - _read_height(x, z - 1, min_height, max_height) * y_step
			else:
				vn_off_z = 0 # For z_inf and boundaries
			var vn := Vector3(-2 * vn_off_x, 4 * Settings.terrain_cell_side() / n, -2 * vn_off_z).normalized()
			mdt.set_vertex_normal(v_id, vn)
			#print("Normal: " + str(vn))
			var vt := Plane(vn.cross(Vector3.FORWARD).normalized())
			mdt.set_vertex_tangent(v_id, vt)
			mdt.set_vertex(v_id, Vector3(v_x, v_y, v_z))
	SLog.sd("[timing] Set heights in " + str(Time.get_ticks_msec() - start_time) + "ms")

	start_time = Time.get_ticks_msec()
	mesh.clear_surfaces()
	mdt.commit_to_surface(mesh)
	SLog.sd("[timing] Committed heights in " + str(Time.get_ticks_msec() - start_time) + "ms")

	return mesh


func _read_height(x: int, z: int, min_height: float, max_height: float) -> float:
	return read_height(_last_heightmap, x, z, min_height, max_height)

static func read_height(hm: Image, x: int, z: int, min_height: float, max_height: float) -> float:
	var color              := hm.get_pixel(x, z)
	const precision: float =  255.99999
	var height: float      =  color.r + color.g / precision
	return height * (max_height - min_height) + min_height

static func read_height_interpolated(hm: Image, x: float, z: float, min_height: float, max_height: float) -> float:
	# Get integer parts of the coordinates (with clamp for added)
	var x0 = int(floor(x))
	var z0 = int(floor(z))
	var x1 = min(x0 + 1, hm.get_width() - 1)
	var z1 = min(z0 + 1, hm.get_height() - 1)

	# Get fractional parts of the coordinates
	var tx = x - x0
	var tz = z - z0

	# Read heights at the four corners
	var h00 = read_height(hm, x0, z0, min_height, max_height)
	var h10 = read_height(hm, x1, z0, min_height, max_height)
	var h01 = read_height(hm, x0, z1, min_height, max_height)
	var h11 = read_height(hm, x1, z1, min_height, max_height)

	# Perform bilinear interpolation
	var h0 = lerp(h00, h10, tx)  # Interpolate in the x-direction
	var h1 = lerp(h01, h11, tx)  # Interpolate in the x-direction at z1
	return lerp(h0, h1, tz)      # Interpolate in the z-direction

func _run_gpu(mseed: int, height_bounds_tex: ImageTexture, water_level_at: float, y_level_step: float, semaphore: Semaphore, xz_counts: Vector2i):
	var start_time := Time.get_ticks_msec()
	self.size = xz_counts

	var mat: Material = $HeightMap.material
	mat.set_shader_parameter("my_seed", mseed)
	Settings.island_water_level_distance_set(height_bounds_tex)
	Settings.island_water_level_at_set(water_level_at)
	Settings.island_water_level_step_set(y_level_step)

	self.set_update_mode(SubViewport.UPDATE_ONCE) # Render once!
	await RenderingServer.frame_post_draw
	var img_tex := get_texture()
	Settings.island_heightmap_set(img_tex)
	if not Engine.is_editor_hint():
		SignalBus.island_global_shader_parameters_ready.emit()
	var img: Image = img_tex.get_image()
	#img.save_png("res://island/terrain/scripts/heightmap.png")
	self.set_update_mode(SubViewport.UPDATE_DISABLED)
	SLog.sd("[timing] HeightMap: GPU-generated " + str(size) + " heightmap in " + str(Time.get_ticks_msec() - start_time) + "ms")
	#start_time = Time.get_ticks_msec()
	#var data = img.get_data() # FORMAT_RGBH on PC, FORMAT_RGBA8 on Web...
	#for i in range(data.size() / 2):
	#var t = data.decode_half(2 * i)
	#if i < 10:
	#print(t)
	#print("Test time: " + str(Time.get_ticks_msec() - start_time) + "ms.")
	_last_heightmap = img
	semaphore.post()


func closest_N(width: int, height: int, target_vertices: int):
	# Solve for N using the formula: (N * width + 1) * (N * height + 1) = target_vertices
	# Rearranging the equation: N^2 * width * height + N * (width + height) + 1 = target_vertices
	# This is a quadratic equation in the form: A * N^2 + B * N + C = 0
	var A: float = width * height
	var B: float = width + height
	var C: float = 1 - target_vertices

	# Using the quadratic formula to find N: N = (-B ± sqrt(B^2 - 4AC)) / 2A
	var discriminant := B**2 - 4 * A * C

	if discriminant < 0:
		return null # No real solution exists, use the minimum of 2

	var N1 := (-B + sqrt(discriminant)) / (2 * A)
	var N2 := (-B - sqrt(discriminant)) / (2 * A)

	# We want the positive solution closest to an integer
	if N1 >= 0:
		return round(N1)
	elif N2 >= 0:
		return round(N2)
	else:
		return 2  # No positive solution exists, use the minimum of 2
