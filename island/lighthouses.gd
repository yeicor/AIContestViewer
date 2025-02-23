@tool
extends Node3D

func _on_terrain_terrain_ready(_mi: MeshInstance3D, game: GameState) -> void:
	GameManager.pause() # Lock the game timer while generating
	var start_time := Time.get_ticks_msec()
	# Clear previous lighthouses
	get_children().map(func(c): c.queue_free())
	# Spawn the lighthouses at the appropriate locations...
	var prev_child: LighthouseScene = null
	for lh_meta in game.lighthouses():
		var hit_pos = IslandH.hit_pos_at_cell(Vector2(lh_meta.pos()) + Vector2(0.5, 0.5))
		var child = LighthouseScene.from_meta(lh_meta, hit_pos)
		add_child(child)
		if prev_child != null: child.connect_to(prev_child) # Only for testing connections
		prev_child = child
	SignalBus.game_state.connect(_on_game_state)
	SLog.sd("[timing] Placed lighthouses in " + str(Time.get_ticks_msec() - start_time) + "ms")
	GameManager.resume()

func _on_game_state(state: GameState, _turn: int, phase: int):
	if phase == SignalBus.GAME_STATE_PHASE_INIT:
		var lhs_meta = state.lighthouses()
		for lh_index in range(lhs_meta.size()):
			var lh_meta: Lighthouse = lhs_meta[lh_index]
			var lh: LighthouseScene = get_child(lh_index)
			lh.color = ColorGenerator.get_color(lh_meta.owner()) if lh_meta.owner() >= 0 else Color.DIM_GRAY
