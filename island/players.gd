@tool
extends Node3D

func _on_terrain_terrain_ready(mi: MeshInstance3D, game: GameState) -> void:
	GameManager.pause() # Lock the game timer while generating
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
	SignalBus.game_state.connect(_on_game_state)
	SLog.sd("[timing] Spawned players in " + str(Time.get_ticks_msec() - start_time) + "ms")
	GameManager.resume()


var player_to_next_pos: Dictionary = {}  # Precomputed during init, start animation on next phase
func _on_game_state(state: GameState, _turn: int, phase: int):
	if phase == SignalBus.GAME_STATE_PHASE_INIT:
		player_to_next_pos.clear()
		var state_players := state.players()
		# First pass: fill the following collision dictionary
		var cell_to_players: Dictionary = {}
		for player_index in range(state_players.size()):
			var player_meta: Player = state_players[player_index]
			var player: PlayerScene = get_child(player_index)
			var cell = player_meta.pos()
			cell_to_players.get_or_add(cell, []).append(player)
		# Second pass, compute actual collision-avoiding next locations for each player.
		for cell in cell_to_players:
			var players_in_cell: Array = cell_to_players[cell]
			var cell_has_lighthouse = false
			if len(players_in_cell) == 1: # Also test if there are lighthouses in this cell.
				for lh_meta in state.lighthouses():
					if lh_meta.pos() == cell:
						cell_has_lighthouse = true
			for player_index_in_cell in range(players_in_cell.size()):
				var player = players_in_cell[player_index_in_cell]
				var actual_target_cell := Vector2(cell) + Vector2i.ONE * 0.5
				if len(players_in_cell) > 1 or cell_has_lighthouse:
					actual_target_cell = actual_target_cell + 1.0/3.0 * Vector2(
						cos(float(player_index_in_cell) / len(players_in_cell) * PI * 2),
						sin(float(player_index_in_cell) / len(players_in_cell) * PI * 2))
				player_to_next_pos[player] = IslandH.cell_to_global(actual_target_cell)

	elif phase == SignalBus.GAME_STATE_PHASE_ANIMATE:
		# Apply precomputed collision-avoiding target walk locations!
		for player in player_to_next_pos:
			var target_pos = player_to_next_pos[player]
			if target_pos != Vector2(player.position.x, player.position.y):
				player.walk_to(target_pos)
			#elif attack!
			else:
				player.idle()
				
	else: # SignalBus.GAME_STATE_PHASE_END
		for player in player_to_next_pos:
			var target_pos = player_to_next_pos[player]
			if target_pos != Vector2(player.position.x, player.position.y):
				player.set_pos(target_pos) # Force it (shouldn't be necessary...)
