class_name MeshGen

## from_heightmap generates a mesh from a 2D array of heights.
static func from_heightmap(grid: Array, center: Vector2 = Vector2.ZERO, cell_size: float = 1.0, scale_y: float = 1.0) -> Mesh:
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(grid.size()):
		for x in range(grid[z].size()):
			var bl_height: float = grid[z][x] * scale_y
			var br_height: float = grid[z][min(x+1, grid[z].size()-1)] * scale_y
			var tl_height: float = grid[min(z+1, grid.size()-1)][x] * scale_y
			var tr_height: float = grid[min(z+1, grid.size()-1)][min(x+1, grid[z].size()-1)] * scale_y

			var left: float   = center.x + (x/grid[z].size() - 0.5) * cell_size
			var right: float  = center.x + ((x+1)/grid[z].size() - 0.5) * cell_size
			var top: float    = center.y + (z/grid.size() - 0.5) * cell_size
			var bottom: float = center.y + ((z+1)/grid.size() - 0.5) * cell_size

			var bottom_left: Vector3  = Vector3(left, bl_height, bottom)
			var bottom_right: Vector3 = Vector3(right, br_height, bottom)
			var top_left: Vector3     = Vector3(left, tl_height, top)
			var top_right: Vector3    = Vector3(right, tr_height, top)

			mesh.surface_add_vertex(top_left)
			mesh.surface_add_vertex(top_right)
			mesh.surface_add_vertex(bottom_left)

			mesh.surface_add_vertex(top_right)
			mesh.surface_add_vertex(bottom_right)
			mesh.surface_add_vertex(bottom_left)
	mesh.surface_end()
	print("Generated mesh from heightmap with " + str(mesh.get_faces().size()) + " faces")
	return mesh

