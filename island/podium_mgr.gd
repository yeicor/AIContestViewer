extends Node3D

@export var players_node: Node3D

var rng := RandomNumberGenerator.new() # Reuse for different location sequences

func _ready() -> void:
	rng.seed = Settings.common_seed() - 1
	if not SignalBus.game_state.is_connected(_on_game_state):
		SignalBus.game_state.connect(_on_game_state)

func _on_game_state(state: GameState, turn: int, phase: int):
	if phase == SignalBus.GAME_STATE_PHASE_INIT and turn == 0:
		while get_child_count() > 0: get_child(0).free()
	if phase == SignalBus.GAME_STATE_PHASE_END_ROUND:
		# Find a place to drop the podium into
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
		podium.look_at_from_position(podium_pos, podium_pos - podium_pos * Vector3(1, 0, 1))
		
		# Animate all players walking toward their expected podium positions
		var i := [0]
		var indexed_scores := state.players().map(func(pl): 
			i[0] += 1
			return [i[0] - 1, pl.score()])
		indexed_scores.sort_custom(func(sco1, sco2): return sco1[1] > sco2[1])
		var position_in_natural_order := indexed_scores.map(func(ind): return ind[0])
		var pl_i = 0
		for player in players_node.get_children():
			var pl := player as PlayerScene
			var order = position_in_natural_order[pl_i]
			_animate_player(pl, order, podium)
			pl_i += 1

func _animate_player(pl: PlayerScene, order: int, podium: Podium):
	var t := podium.transform_for_player(order)
	var final_t := podium.transform * t
	if t.origin.y == 0: # order >= 4 --> place on the ground
		final_t.origin.y = IslandH.height_at_global(Vector2(final_t.origin.x, final_t.origin.z))
	var walk_time: float = min(3.0, Settings.common_end_turn_secs() / 3.0)
	pl.walk_to_3d(final_t.origin, walk_time)
	await get_tree().create_timer(walk_time).timeout
	#var dance_time := Settings.common_end_turn_secs() - walk_time
	pl.podium(order, final_t.translated_local(Vector3.BACK).origin)
	#await get_tree().create_timer(dance_time).timeout
	#pl.idle()
