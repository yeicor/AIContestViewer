extends Node3D

@export var players_node: Node3D

func _ready() -> void:
	if not SignalBus.game_state.is_connected(_on_game_state):
		SignalBus.game_state.connect(_on_game_state)

func _on_game_state(state: GameState, _turn: int, phase: int):
	if phase == SignalBus.GAME_STATE_PHASE_END_ROUND:
		# TODO: Is pause necessary?
		#GameManager.pause() # Keep working on this animation until the last player is in position and animated
		# Find a place to drop the podium into
		var rng := RandomNumberGenerator.new()
		rng.seed = Settings.common_seed() - 1
		var podium_cell_center: Vector2
		while true: # Until a suitable cell is found...
			podium_cell_center = Vector2(
				rng.randi_range(0, IslandH.num_cells().x),
				rng.randi_range(0, IslandH.num_cells().y)) + Vector2.ONE * 0.5
			if IslandH.height_at_cell(podium_cell_center) > 0: break
		
		# Spawn the podium
		Log.d("Dropping podium at cell", podium_cell_center)
		var podium: Podium = preload("res://island/podium/podium.tscn").instantiate()
		podium.name = "Podium"
		podium.scale = Vector3.ONE * Settings.player_scale()
		# TODO: Transform according to terrain normals?
		add_child(podium)
		var podium_pos := IslandH.hit_pos_at_cell(podium_cell_center)
		if podium_pos.is_zero_approx(): podium_pos += Vector3(Settings.terrain_cell_side() / 10.0, 0, 0)
		podium.look_at_from_position(podium_pos, podium_pos + podium_pos * Vector3(1, 0, 1))
		
		# Animate all players walking toward their expected podium positions
		var i := [0]
		var indexed_scores := state.players().map(func(pl): 
			i[0] += 1
			return [i[0] - 1, pl.score()])
		indexed_scores.sort_custom(func(sco1, sco2): return sco1[1] > sco2[1])
		var position_in_natural_order := indexed_scores.map(func(ind): return ind[0])
		var pl_i = 0
		i = [0]
		for player in players_node.get_children():
			var pl := player as PlayerScene
			var order = position_in_natural_order[pl_i]
			pl_i += 1
			var final_pos := podium.transform * podium.transform_for_player(order)
			# Walk right behind your expected position...
			var first_walk_time: float = min(3.0, Settings.common_end_turn_secs() / 3.0)
			var first_walk_pos: = final_pos.translated(2.0 * Vector3.BACK)
			# FIXME: Really bad offset
			pl.walk_to_3d(first_walk_pos.origin, first_walk_time)
			# ...followed by walking towards the camera to ensure proper rotation
			get_tree().create_timer(first_walk_time).timeout.connect(func():
				var second_walk_time: float = min(3.0, Settings.common_end_turn_secs() / 3.0)
				pl.walk_to_3d(final_pos.origin, second_walk_time)
				get_tree().create_timer(second_walk_time).timeout.connect(func():
					var dance_time := Settings.common_end_turn_secs() - first_walk_time - second_walk_time
					pl.podium(order)
					get_tree().create_timer(dance_time).timeout.connect(func():
						pl.idle()
						i[0] += 1
						if i[0] == players_node.get_child_count():
							remove_child(podium)
							podium.queue_free()
							#GameManager.resume()
							, CONNECT_ONE_SHOT), CONNECT_ONE_SHOT), CONNECT_ONE_SHOT)
		
