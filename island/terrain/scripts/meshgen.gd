class_name MeshGen

## from_heightmap generates a mesh from a 2D array of heights (X, Z).
static func from_heightmap(grid: Array, quad_size: Vector3 = Vector3.ONE, extend_to_bottom: float = 10000.0) -> Mesh:
	var start_time  := Time.get_ticks_msec()
	var quad_counts := Vector2(grid[0].size(), grid.size())
	var plane_mesh  =  PlaneMesh.new()
	plane_mesh.subdivide_width = quad_counts.x  # Adds borders automatically for extend to bottom!
	plane_mesh.subdivide_depth = quad_counts.y
	plane_mesh.size = Vector2(quad_size.x, quad_size.z) * quad_counts
	var st          =  SurfaceTool.new()
	st.create_from(plane_mesh, 0)
	var mesh = st.commit()
	print("[timing] Generated plane for heightmap of size " + str(quad_counts) +
	" in " + str(Time.get_ticks_msec() - start_time) + "ms")

	var start_time_2 := Time.get_ticks_msec()
	var mdt          =  MeshDataTool.new()
	var error        =  mdt.create_from_surface(mesh, 0)
	if error != OK:
		print("Error creating MeshDataTool from plane: " + str(error))
		return null
	print("[timing] Created MeshDataTool from plane in " + str(Time.get_ticks_msec() - start_time_2) + "ms")

	start_time_2 = Time.get_ticks_msec()
	var v_off = plane_mesh.size / 2;
	for z in range(-1, quad_counts.y + 1):
		var z_off := (z + 1) * (quad_counts.x + 2)
		var z_inf := z < 0 or z >= quad_counts.y
		for x in range(-1, quad_counts.x + 1):
			var v_id = (x + 1) + z_off;
			var x_inf := x < 0 or x >= quad_counts.x
			var v_x   =  x * quad_size.x * (1 + 1.0 / quad_counts.x) - v_off.x
			var v_z   =  z * quad_size.z * (1 + 1.0 / quad_counts.y) - v_off.y
			var v_y   := -extend_to_bottom
			if z_inf or x_inf:
				v_x += extend_to_bottom * 2 * (x - quad_counts.x / 2) / quad_counts.x
				v_z += extend_to_bottom * 2 * (z - quad_counts.y / 2) / quad_counts.y
				var vn := Vector3(0, 1, 0).normalized()
				mdt.set_vertex_normal(v_id, vn)
				var vt := Plane(vn.cross(Vector3.FORWARD).normalized())
				mdt.set_vertex_tangent(v_id, vt)
			else:
				v_y = grid[z][x] * quad_size.y
				var vn_off_x: float
				if x + 1 < quad_counts.x and x - 1 >= 0:
					vn_off_x = grid[z][x + 1] * quad_size.y - grid[z][x - 1] * quad_size.y
				else:
					vn_off_x = 0 # For x_inf and boundaries
				var vn_off_z: float
				if z + 1 < quad_counts.y and z - 1 >= 0:
					vn_off_z = grid[z+1][x] * quad_size.y - grid[z-1][x] * quad_size.y
				else:
					vn_off_z = 0 # For z_inf and boundaries
				var vn := Vector3(-2 * vn_off_x, 4, -2 * vn_off_z).normalized()
				mdt.set_vertex_normal(v_id, vn)
				var vt := Plane(vn.cross(Vector3.FORWARD).normalized())
				mdt.set_vertex_tangent(v_id, vt)
			mdt.set_vertex(v_id, Vector3(v_x, v_y, v_z))
	print("[timing] Set heights in " + str(Time.get_ticks_msec() - start_time_2) + "ms")

	start_time_2 = Time.get_ticks_msec()
	mesh.clear_surfaces()
	mdt.commit_to_surface(mesh)
	print("[timing] Committed heights in " + str(Time.get_ticks_msec() - start_time_2) + "ms")

	print("[timing] TOTAL: Generated mesh from heightmap of size " + str(quad_counts) +
	 " in " + str(Time.get_ticks_msec() - start_time) + "ms")
	return mesh

