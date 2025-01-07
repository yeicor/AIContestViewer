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
		for i in len(players):
			var pl: Player = players[i]
			var pl_node: PlayerUI = get_node_or_null(NodePath(pl.name()))
			if pl_node == null:
				pl_node = _player_scene.instantiate()
				pl_node.name = pl.name()
				if get_child_count() > 0:
					var my_sep = get_parent().get_node("Separator").duplicate()
					my_sep.custom_minimum_size.y /= 2
					add_child(my_sep)
				add_child(pl_node)
			pl_node.on_game_state_update(pl, i, max_score, max_energy)
