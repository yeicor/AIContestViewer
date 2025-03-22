@tool
extends Node3D

@export var lighthousesParent: Node3D

func _on_terrain_terrain_ready(_mi: MeshInstance3D, game: GameState) -> void:
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
		player.name = "Player" + str(player_index) + "@" + player_meta.name()
		player.position = spawn_pos
		player.color = ColorGenerator.get_color(player_index)
		add_child(player)
	if not SignalBus.game_state.is_connected(_on_game_state):
		SignalBus.game_state.connect(_on_game_state)
	SLog.sd("[timing] Spawned players in " + str(Time.get_ticks_msec() - start_time) + "ms")
	GameManager.resume()


var _player_to_next_pos: Dictionary = {}  # Precomputed during init, start animation on next phase
var _player_attacks: Dictionary = {}
var _last_players: Array = []
func _on_game_state(state: GameState, turn: int, phase: int):
	if turn == 0: 
		_player_to_next_pos.clear()
		_last_players.clear()
	if phase == SignalBus.GAME_STATE_PHASE_INIT:
		# => PRECOMPUTE MOVEMENT DATA
		_player_to_next_pos.clear()
		var state_players := state.players()
		# First pass: fill the following collision dictionary
		var cell_to_players: Dictionary = {}
		for player_index in range(state_players.size()):
			var player_meta: Player = state_players[player_index]
			var player: PlayerScene = get_child(player_index)
			var cell = player_meta.pos()
			cell_to_players.get_or_add(cell, []).append([player_index, player])
		# Second pass, compute actual collision-avoiding next locations for each player.
		for cell in cell_to_players:
			var players_in_cell: Array = cell_to_players[cell]
			var cell_has_lighthouse = false
			if len(players_in_cell) == 1: # Also test if there are lighthouses in this cell.
				for lh_meta in state.lighthouses():
					if lh_meta.pos() == cell:
						cell_has_lighthouse = true
			for player_index_in_cell in range(players_in_cell.size()):
				var player = players_in_cell[player_index_in_cell][1]
				var actual_target_cell := Vector2(cell) + Vector2i.ONE * 0.5
				if len(players_in_cell) > 1 or cell_has_lighthouse:
					# TODO: Player 0 prefers the side of the camera to make animations more noticeable
					actual_target_cell = actual_target_cell + 1.0/3.0 * Vector2(
						cos(float(player_index_in_cell) / len(players_in_cell) * PI * 2),
						sin(float(player_index_in_cell) / len(players_in_cell) * PI * 2))
				var prev_pos = Vector2(player.position.x, player.position.z)
				if Vector2i(IslandH.global_to_cell(prev_pos)) != Vector2i(cell): # Only move when needed! (not 100% valid in case of idles, but good enough)
					_player_to_next_pos[player] = IslandH.cell_to_global(actual_target_cell)
		
		# => PRECOMPUTE ATTACK/CONNECTION DATA (defaults to it if next to lighthouse, otherwise idle)
		_player_attacks.clear()
		for cell in cell_to_players: # "Optimization": only check lighthouses with players
			for lh_meta in state.lighthouses():
				if lh_meta.pos() == cell:
					var attacks = []
					for player_info in cell_to_players[cell]:
						var pl_i = player_info[0]
						var player_energy_delta = 0
						if len(_last_players) > pl_i:
							player_energy_delta = state_players[pl_i].energy() - _last_players[pl_i].energy()
						attacks.append([player_info, max(1, -player_energy_delta)]) # If not attacking, connecting!
					# Compute relative attack energies
					var max_attack_energy = attacks.map(func(x): return x[1]).max()
					_player_attacks[cell] = attacks.map(func(x): return [x[0], float(x[1]) / max_attack_energy])
		

	elif phase == SignalBus.GAME_STATE_PHASE_ANIMATE:
		var players := state.players()
		for player_index in range(players.size()):
			var player_meta = players[player_index]
			var player: PlayerScene = get_child(player_index)
			var target_pos = _player_to_next_pos.get(player)
			if target_pos != null: # Apply precomputed collision-avoiding target walk locations!
				player.walk_to(target_pos)
			elif _player_attacks.has(player_meta.pos()): # Attack / connect
				var attack_pos = IslandH.hit_pos_at_cell(Vector2(player_meta.pos()) + Vector2.ONE * 0.5)
				var lh_height = 20
				if lighthousesParent.get_child_count() > 0:
					lh_height = lighthousesParent.get_child(0).top_center.y
				attack_pos.y += lh_height
				var attack_energy = _player_attacks[player_meta.pos()].filter(func(x): return x[0][0] == player_index)[0][1]
				player.attack(attack_pos, attack_energy)
			else: # Default to idle otherwise
				player.idle()
				
	elif SignalBus.GAME_STATE_PHASE_END:
		for player in _player_to_next_pos:
			var target_pos = _player_to_next_pos[player]
			if target_pos != Vector2(player.position.x, player.position.y):
				player.set_pos(target_pos) # Force it (shouldn't be necessary...)
		_last_players = state.players()
