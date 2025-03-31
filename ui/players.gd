extends VBoxContainer

var _player_scene := preload("res://ui/player.tscn")

# Since players get reset after loading a new map, keep their energy offsets 
var _score_offsets := {}
var _score_offsets_last := {}

func _ready() -> void:
	SignalBus.game_state.connect(self._on_game_state)

func _on_game_state(state: GameState, turn: int, phase: int):
	if phase == SignalBus.GAME_STATE_PHASE_INIT:
		var players = state.players()
		var max_score := -1
		var max_energy := -1
		for i in len(players):
			var pl: Player = players[i]
			var raw_score := pl.score()
			var pl_name = pl.name()
			if turn == 0:
				_score_offsets[pl_name] = _score_offsets_last.get_or_add(pl_name, 0)
				
			var score: int = _score_offsets[pl_name] + raw_score
			_score_offsets_last[pl_name] = score
			max_score = max(max_score, score)
			max_energy = max(max_energy, pl.energy())
		var player_name_to_score := {}
		for i in len(players):
			var pl: Player = players[i]
			var pl_node: PlayerUI = get_node_or_null(NodePath(pl.name()))
			if pl_node == null:
				pl_node = _player_scene.instantiate()
				pl_node.name = pl.name()
				if get_child_count() > 0:
					var my_sep = get_parent().get_node("Separator").duplicate()
					my_sep.name = "___Separator___" + str(Time.get_ticks_usec())
					my_sep.custom_minimum_size.y /= 2
					add_child(my_sep)
				add_child(pl_node)
			var accum_score: int = _score_offsets_last[pl_node.name]
			player_name_to_score[pl_node.name] = accum_score
			var color := ColorGenerator.get_color(i, players)
			pl_node.on_game_state_update(pl, color, accum_score, max_score, max_energy)
		# Sort players UI by current accum_score!
		var sorted_children = get_children().filter(func(c): 
			return not c.name.begins_with("___Separator___"))
		sorted_children.sort_custom(func(a, b): # "Stable" sort
			var score_a: int = player_name_to_score[a.name]
			var score_b: int = player_name_to_score[b.name]
			return score_a < score_b or score_a == score_b and a.name < b.name)
		var cur_idx := 0
		for c in get_children():
			if c.name.begins_with("___Separator___"): continue # Keep it
			# Since sorted_children is sorted, move first c out of the way!
			var move_from: int = sorted_children[cur_idx].get_index()
			var move_to := c.get_index()
			# Avoid moving if the score is the same!
			if move_to != move_from:
				move_child(c, move_from)
				move_child(sorted_children[cur_idx], move_to)
			cur_idx += 1
