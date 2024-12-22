@tool
extends Node3D

func _on_terrain_terrain_ready(mi: MeshInstance3D, game: GameState) -> void:
	var start_time := Time.get_ticks_msec()
	# Clear previous players
	get_children().map(func(c): c.queue_free())
	# Spawn each player as determined by the inital state
	var game_players := game.players()
	for player_index in range(game_players.size()):
		var player_meta: Player = game_players[player_index]
		var spawn_pos := IslandH.hit_pos_at_cell(Vector2(player_meta.pos()) + Vector2(0.5, 0.5))
		
		var player = preload("res://island/player/player.tscn").instantiate()
		player.terrain_mi = mi
		player.name = "Player" + str(player_index) + "@" + player_meta.name()
		player.position = spawn_pos
		player.scale = Vector3.ONE * 5.0 # TODO: Use specialized method to place outside lighthouse if needed...
		player.rotate_y(randf() * 2 * PI)
		player.color = ColorGenerator.get_color(player_index)
		add_child(player)
	SLog.sd("[timing] Spawned players in " + str(Time.get_ticks_msec() - start_time) + "ms")
		
		
		
	
