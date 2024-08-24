@tool
class_name HeightMap
extends SubViewport

var _last_heightmap: Image  # Don't call too fast, not properly synchronized

func _init():
	self.set_update_mode(SubViewport.UPDATE_DISABLED)

func generate(game: GameState, mseed: int, cell_side: float, steepness: float, target_vertices: int) -> Mesh:
	# Create the max heights texture for the shader
	var island               := game.island(false)
	var height_bounds: Array =  island.distance_to_water_level()
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
	print("[timing] HeightMap: Created max heights texture in " + str(Time.get_ticks_msec() - start_time) + "ms  (excluding distance to water level)")

	# Figure out the number of pixels to generate based on the target vertices
	var gen_ratio_xz: float = float(island.width()) / float(island.height())
	var gen_width: int  = int(sqrt(target_vertices) * gen_ratio_xz)
	var gen_height: int = int(sqrt(target_vertices) / gen_ratio_xz)

	# Use the shader to render the high-res heightmap to another texture ("blocking" the main thread!)
	var gpu_semaphore := Semaphore.new()
	var xz_counts  := Vector2(gen_width, gen_height)
	_run_gpu.call_deferred(mseed, height_bounds_tex, water_level_at, y_level_step, gpu_semaphore, xz_counts)

	# Mean-while, prepare the plane mesh in the CPU!
	start_time = Time.get_ticks_msec()
	var xz_step    := Vector2(cell_side, cell_side) * Vector2(game.island().size()) / xz_counts
	var y_step     := steepness * cell_side / 2
	var plane_mesh =  PlaneMesh.new()
	plane_mesh.subdivide_width = xz_counts.x  # Adds borders automatically for extend to bottom!
	plane_mesh.subdivide_depth = xz_counts.y
	plane_mesh.size = xz_step * xz_counts
	var st         =  SurfaceTool.new()
	st.create_from(plane_mesh, 0)
	var mesh = st.commit()
	print("[timing] Generated plane for heightmap of size " + str(xz_counts) +
	" in " + str(Time.get_ticks_msec() - start_time) + "ms")

	start_time = Time.get_ticks_msec()
	var mdt   = MeshDataTool.new()
	var error = mdt.create_from_surface(mesh, 0)
	if error != OK:
		print("Error creating MeshDataTool from plane: " + str(error))
		return null
	print("[timing] Created MeshDataTool from plane in " + str(Time.get_ticks_msec() - start_time) + "ms")

	# Ensure the GPU-generated heightmap is ready before proceeding to read it
	start_time = Time.get_ticks_msec()
	gpu_semaphore.wait()
	print("[timing] CPU was waiting for GPU to generate heightmap for " + str(Time.get_ticks_msec() - start_time) + "ms")

	start_time = Time.get_ticks_msec()
	var v_off = plane_mesh.size / 2;
	var extend_to_bottom := 10000.0;
	for z in range(-1, xz_counts.y + 1):
		var z_off := (z + 1) * (xz_counts.x + 2)
		var z_inf := z < 0 or z >= xz_counts.y
		for x in range(-1, xz_counts.x + 1):
			var v_id = (x + 1) + z_off;
			var x_inf := x < 0 or x >= xz_counts.x
			var v_x   =  x * xz_step.x * (1 + 1.0 / xz_counts.x) - v_off.x
			var v_z   =  z * xz_step.y * (1 + 1.0 / xz_counts.y) - v_off.y
			var v_y   := -extend_to_bottom * 0.3
			if z_inf or x_inf:
				v_x += extend_to_bottom * 2 * (x - xz_counts.x / 2) / xz_counts.x
				v_z += extend_to_bottom * 2 * (z - xz_counts.y / 2) / xz_counts.y
				var vn := Vector3(0, 1, 0).normalized()
				mdt.set_vertex_normal(v_id, vn)
				var vt := Plane(vn.cross(Vector3.FORWARD).normalized())
				mdt.set_vertex_tangent(v_id, vt)
			else:
				v_y = _read_height(x, z, min_height, max_height) * y_step
				var vn_off_x: float
				if x + 1 < xz_counts.x and x - 1 >= 0:
					vn_off_x = _read_height(x + 1, z, min_height, max_height) * y_step - _read_height(x - 1, z, min_height, max_height) * y_step
				else:
					vn_off_x = 0 # For x_inf and boundaries
				var vn_off_z: float
				if z + 1 < xz_counts.y and z - 1 >= 0:
					vn_off_z = _read_height(x, z + 1, min_height, max_height) * y_step - _read_height(x, z - 1, min_height, max_height) * y_step
				else:
					vn_off_z = 0 # For z_inf and boundaries
				var vn := Vector3(-2 * vn_off_x, 4, -2 * vn_off_z).normalized()
				mdt.set_vertex_normal(v_id, vn)
				var vt := Plane(vn.cross(Vector3.FORWARD).normalized())
				mdt.set_vertex_tangent(v_id, vt)
			mdt.set_vertex(v_id, Vector3(v_x, v_y, v_z))
	print("[timing] Set heights in " + str(Time.get_ticks_msec() - start_time) + "ms")

	start_time = Time.get_ticks_msec()
	mesh.clear_surfaces()
	mdt.commit_to_surface(mesh)
	print("[timing] Committed heights in " + str(Time.get_ticks_msec() - start_time) + "ms")

	return mesh


func _read_height(x: int, z: int, min_height: float, max_height: float) -> float:
	var color              := _last_heightmap.get_pixel(x, z)
	const precision: float =  256.0
	var height: float      =  color.r + color.g / precision
	return height * (max_height - min_height) + min_height


func _run_gpu(mseed: int, height_bounds_tex: ImageTexture, water_level_at: float, y_level_step: float, semaphore: Semaphore, xz_counts: Vector2i):
	var start_time    := Time.get_ticks_msec()
	self.size = xz_counts
	
	var mat: Material =  $HeightMap.material
	mat.set_shader_parameter("my_seed", mseed)
	Settings.island_water_level_distance_set(height_bounds_tex)
	Settings.island_water_level_set(water_level_at)
	Settings.island_water_level_step_set(y_level_step)
	if not Engine.is_editor_hint():
		SignalBus.island_global_shader_parameters_ready.emit()
	
	self.set_update_mode(SubViewport.UPDATE_ONCE) # Render once!
	await RenderingServer.frame_post_draw
	var img: Image = get_texture().get_image()
	#img.save_png("res://island/terrain/scripts/heightmap.png")
	self.set_update_mode(SubViewport.UPDATE_DISABLED)
	print("[timing] HeightMap: GPU-generated " + str(size) + " heightmap in " + str(Time.get_ticks_msec() - start_time) + "ms. Format: " + str(img.get_format()))
	#start_time = Time.get_ticks_msec()
	#var data = img.get_data() # FORMAT_RGBH on PC, FORMAT_RGBA8 on Web...
	#for i in range(data.size() / 2):
		#var t = data.decode_half(2 * i)
		#if i < 10:
			#print(t)
	#print("Test time: " + str(Time.get_ticks_msec() - start_time) + "ms.")
	_last_heightmap = img
	semaphore.post()
	
