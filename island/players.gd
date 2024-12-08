@tool
extends Node3D

func _on_terrain_terrain_ready(mi: MeshInstance3D, game: GameState) -> void:
	IslandH.ensure_terrain_collision(mi)
	var start_time := Time.get_ticks_msec()
	# Clear previous players
	get_children().map(func(c): c.queue_free())
	# Spawn each player as determined by the inital state
	for player_meta in game.players():
		var player_global_center = IslandH.cell_to_global(Vector2(player_meta.pos()) + Vector2(0.5, 0.5))
		var hit = IslandH.query_terrain(mi, player_global_center)
		var spawn_pos: Vector3
		if not hit:
			print("Cannot find height to spawn player at, defaulting to 0")
			spawn_pos = Vector3(player_global_center.x, 0.0, player_global_center.y)
		else:
			spawn_pos = hit.position
		
		var player = preload("res://island/player/player.tscn").instantiate()
		player.name = "Player@" + player_meta.name()
		player.position = spawn_pos
		player.scale = Vector3.ONE * 5.0 # TODO: Use specialized method to place outside lighthouse if needed...
		player.rotate_y(randf() * 2 * PI)
		player.color = Color(randf(), randf(), randf())
		add_child(player)
	SLog.sd("[timing] Spawned players in " + str(Time.get_ticks_msec() - start_time) + "ms")
		
		
		
	
