@tool
extends Node3D

@export var lhTriAreasParent: Node3D

var current_conns = {}
var current_tris = {}
func _on_terrain_terrain_ready(_mi: MeshInstance3D, game: GameState) -> void:
	GameManager.pause() # Lock the game timer while generating
	var start_time := Time.get_ticks_msec()
	# Clear previous lighthouses
	get_children().map(func(c): c.queue_free())
	# Spawn the lighthouses at the appropriate locations...
	for lh_meta in game.lighthouses():
		var hit_pos = IslandH.hit_pos_at_cell(Vector2(lh_meta.pos()) + Vector2(0.5, 0.5))
		add_child(LighthouseScene.from_meta(lh_meta, hit_pos))
	current_conns = {} # Map has just been reset
	current_tris = {} # Map has just been reset
	SignalBus.game_state.connect(_on_game_state)
	SLog.sd("[timing] Placed lighthouses in " + str(Time.get_ticks_msec() - start_time) + "ms")
	GameManager.resume()

func _on_game_state(state: GameState, _turn: int, phase: int):
	if phase == SignalBus.GAME_STATE_PHASE_INIT:
		# Update lighthouse owners
		var lhs_meta = state.lighthouses()
		var lh_by_pos = {}
		for lh_index in range(lhs_meta.size()):
			var lh_meta: Lighthouse = lhs_meta[lh_index]
			var lh: LighthouseScene = get_child(lh_index)
			lh_by_pos[lh_meta.pos()] = lh
			lh.color = ColorGenerator.get_color(lh_meta.owner()) if lh_meta.owner() >= 0 else LighthouseScene.unowned_color
		
		# Update lighthouse connections
		var conns_meta = state.connections()
		var next_conns = {}
		var tri_helper = {} # from: [to1, to2...] (both ways!)
		for conn_index in range(conns_meta.size()):
			var conn_meta: Connection = conns_meta[conn_index]
			var lh_from: LighthouseScene = lh_by_pos[conn_meta.from()]
			var lh_to: LighthouseScene = lh_by_pos[conn_meta.to()]
			var stable_key := [lh_from, lh_to]
			stable_key.sort()
			next_conns[stable_key] = true
			if !current_conns.erase(stable_key): # New
				await stable_key[0].connect_to(stable_key[1])
			tri_helper.get_or_add(conn_meta.from(), []).append(conn_meta.to())
			tri_helper.get_or_add(conn_meta.to(), []).append(conn_meta.from())
		for stable_key in current_conns.keys():
			assert(stable_key[0].disconnect_from(stable_key[1]))
		current_conns = next_conns
		
		# Detect triangles
		var triangles := [] #{sorted([tri1, tri2, tri3])}: true
		for tri1 in tri_helper.keys():
			for tri2 in tri_helper[tri1]:
				if tri2 <= tri1: continue # Filter equals and enforce order as optimization
				for tri3 in tri_helper[tri2]:
					if tri3 <= tri2: continue # Filter equals and enforce order as optimization
					if tri3 <= tri1: continue # Filter equals and enforce order as optimization
					for tri_close in tri_helper[tri3]:
						if tri_close == tri1:
							var tri = [tri1, tri2, tri3]
							triangles.append(tri)
		#Log.d("Found triangles ", len(triangles))
		# Update lighthouse connection triangles
		var next_tris := {}
		for tri in triangles:
			next_tris[tri] = true
			if !current_tris.erase(tri): # New
				# TODO(perf): Also pool these MeshInstance nodes? Or use MultiMeshInstance + transforms?
				var n := make_tri_node(tri, lh_by_pos[tri[0]].color)
				n.name = str(tri)
				lhTriAreasParent.add_child(n)
		for tri in current_tris.keys(): # Deleted
			var n := lhTriAreasParent.get_node(str(tri))
			lhTriAreasParent.remove_child(n)
			n.queue_free()
		current_tris = next_tris
			
func make_tri_node(tri: Array, color: Color) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var lh_top_center := Vector3.ONE * 20
	if get_child_count() > 0: # Should always be true...
		lh_top_center = get_child(0).top_center
	var v0: Vector3 = IslandH.hit_pos_at_cell(Vector2(tri[0]) + Vector2.ONE * 0.5) + lh_top_center
	var v1: Vector3 = IslandH.hit_pos_at_cell(Vector2(tri[1]) + Vector2.ONE * 0.5) + lh_top_center
	var v2: Vector3 = IslandH.hit_pos_at_cell(Vector2(tri[2]) + Vector2.ONE * 0.5) + lh_top_center
	var n := (v1 - v0).cross(v2 - v0).normalized()
	if n.y >= 0.0:
		verts.push_back(v0)
		verts.push_back(v2)
		verts.push_back(v1)
	else:
		n = -n
		verts.push_back(v0)
		verts.push_back(v1)
		verts.push_back(v2)
	normals.push_back(n)
	normals.push_back(n)
	normals.push_back(n)
	indices.push_back(0)
	indices.push_back(1)
	indices.push_back(2)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr) # No blendshapes or compression used.
	var mat := StandardMaterial3D.new()
	color.a = 0.1
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1 # Avoid conflict with ocean
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	# TODO: Text overlay with score of area that always looks at camera
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = mesh
	return mesh_node
