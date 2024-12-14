@tool
extends Node3D

func _on_terrain_terrain_ready(mi: MeshInstance3D, game: GameState) -> void:
	IslandH.ensure_terrain_collision(mi)
	var start_time := Time.get_ticks_msec()
	# Clear previous lighthouses
	get_children().map(func(c): c.queue_free())
	# Spawn the lighthouses at the appropriate locations...
	var prev_child: LighthouseScene = null
	for lh_meta in game.lighthouses():
		var lh_global_center = IslandH.cell_to_global(Vector2(lh_meta.pos()) + Vector2(0.5, 0.5))
		var hit = IslandH.query_terrain(mi, lh_global_center)
		if hit:
			var child = LighthouseScene.from_meta(lh_meta, hit.position)
			add_child(child)
			if prev_child != null: child.connect_to(prev_child) # Only for testing connections
			prev_child = child
		else:
			SLog.se("ERROR: Couldn't hit raycast to place lighthouse!!!")
	SLog.sd("[timing] Placed lighthouses in " + str(Time.get_ticks_msec() - start_time) + "ms")
