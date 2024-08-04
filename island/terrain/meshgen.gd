class_name MeshGen

## from_heightmap generates a mesh from a 2D array of heights (X, Z).
static func from_heightmap(grid: Array, cell_size: Vector3 = Vector3.ONE, offset_pct: Vector3 = Vector3(0.5, -1, 0.5)) -> Mesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var min_y: float         = grid.map(func(x): return x.min()).min()
	var max_y: float         = grid.map(func(x): return x.max()).max()
	var cell_counts: Vector3 = Vector3(grid[0].size()+1, max_y - min_y, grid.size()-1)
	var origin: Vector3      = -offset_pct * cell_size * cell_counts
	
	if offset_pct.y < 0:
		origin.y = min_y # Keep original y values

	# Generate vertices and faces
	for z in range(grid.size()):
		for x in range(grid[z].size()):
			var p: Vector3 = Vector3(x, grid[z][x] - min_y, z) * cell_size + origin
			st.set_smooth_group(0)
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
	
	# TODO: Option to expand corners and edges towards -inf
	
	var mesh: ArrayMesh = st.commit()
	print("Generated mesh from heightmap with " + str(mesh.get_faces().size()) + " faces")
	return mesh

