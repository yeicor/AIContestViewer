@tool
extends MeshInstance3D

func _init():
	if Settings.ocean_screen_and_depth():
		var mat := self.material_override as ShaderMaterial
		mat.shader.code = "#define depth_and_screen\n" + mat.shader.code

func _ready():
	if not Engine.is_editor_hint() and (mesh as PlaneMesh).subdivide_width != 0 and OS.has_feature("standalone"):
		print("[ocean] WARNING: This build has subdivide_width != 0. This should have been changed before exporting...")
		set_map_size(0, 0); # Leave basic quad until it is configured in case of runtime.

func set_map_size(width: float, depth: float):
	var pmesh := mesh as PlaneMesh
	var extra: float = 1.2;
	pmesh.size = Vector2(width, depth) * extra
	self.material_override.set_shader_parameter("far_away", pmesh.size / 2.0 - Vector2(1.0, 1.0))
	pmesh.subdivide_depth = int(sqrt(Settings.ocean_vertex_count()))
	pmesh.subdivide_width = pmesh.subdivide_depth
	print("Ocean has ", pmesh.subdivide_width, "x", pmesh.subdivide_depth, " cells")
