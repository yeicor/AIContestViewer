class_name MeshGen

## from_heightmap generates a mesh from a 2D array of heights (X, Z).
static func from_heightmap(grid: Array, cell_size: Vector3 = Vector3.ONE, offset_pct: Vector3 = Vector3(0.5, -1, 0.5), extend_to_bottom: float = 0.0) -> Mesh:
	var start_time = Time.get_ticks_msec()
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var min_y: float         = grid.map(func(x): return x.min()).min()
	var max_y: float         = grid.map(func(x): return x.max()).max()
	var cell_counts: Vector3 = Vector3(grid[0].size()+1, max_y - min_y, grid.size()-1)
	var origin: Vector3      = -offset_pct * cell_size * cell_counts
	
	if offset_pct.y < 0:
		origin.y = min_y * cell_size.y # Keep original y values

	# TODO: Create the grid at the same time as the GPU works, (and in another thread to avoid blocking)
	# TODO: Faster with PlaneMesh + displacing vertices?

	if extend_to_bottom > 0: # Add 4 edges to the original grid with large negative y values (slow?)
		var start_time_2 = Time.get_ticks_msec()
		var new_grid: Array = []
		for z in range(grid.size() + 2):
			var row: Array = []
			for x in range(grid[0].size() + 2):
				row.append(-extend_to_bottom)
			new_grid.append(row)
		for z in range(grid.size()):
			for x in range(grid[z].size()):
				new_grid[z+1][x+1] = grid[z][x]
		grid = new_grid
		print("[timing] Extended bottom of grid in " + str(Time.get_ticks_msec() - start_time_2) + "ms")

	# Generate vertices and faces
	for z in range(grid.size()):
		for x in range(grid[z].size()):
			var p: Vector3 = Vector3(x, grid[z][x] - min_y, z) * cell_size + origin
			if extend_to_bottom > 0: # Push outwards
				if x == 0 or x == grid[z].size() - 1:
					var extend_by: float = extend_to_bottom * cell_size.y
					p.x += -extend_by if x == 0 else extend_by
				if z == 0 or z == grid.size() - 1:
					var extend_by: float = extend_to_bottom * cell_size.y
					p.z += -extend_by if z == 0 else extend_by
			st.set_uv(Vector2(x / float(grid[z].size()), z / float(grid.size())))
			st.add_vertex(p)
			if x > 0 and z > 0: # Connect to previous row and column
				var i0: int = z * grid[z].size() + x
				var i1: int = z * grid[z].size() + x - 1
				var i2: int = (z - 1) * grid[z].size() + x
				var i3: int = (z - 1) * grid[z].size() + x - 1
				st.add_index(i0)
				st.add_index(i1)
				st.add_index(i2)
				st.add_index(i1)
				st.add_index(i3)
				st.add_index(i2)

	st.generate_normals()
	st.generate_tangents()

	var mesh: ArrayMesh = st.commit()
	
	print("[timing] Generated mesh from heightmap of size " + str(cell_counts.x) + "x" + str(cell_counts.z) +
	 " in " + str(Time.get_ticks_msec() - start_time) + "ms")
	print("Cell size: ", cell_size)
	
	return mesh

