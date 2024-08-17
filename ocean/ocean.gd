extends MeshInstance3D


# Called when the node enters the scene tree for the first time.
func _ready():
	var pmesh := mesh as PlaneMesh
	pmesh.subdivide_depth = int(sqrt(Setting.ocean_vertex_count()))
	pmesh.subdivide_width = pmesh.subdivide_depth
	print("Ocean has ", pmesh.subdivide_width, "x", pmesh.subdivide_depth, " cells")
