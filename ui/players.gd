extends VBoxContainer

var player_scene := preload("res://ui/player.tscn")

func _ready() -> void:
	SignalBus.game_state.connect(self._on_game_state)

func _on_game_state(state: GameState, _turn: int, phase: int):
	if phase == SignalBus.GAME_STATE_PHASE_INIT:
		var players = state.players()
		var max_score := -1
		var max_energy := -1
		for i in len(players):
			var pl: Player = players[i]
			max_score = max(max_score, pl.score())
			max_energy = max(max_energy, pl.energy())
		for i in len(players):
			var pl: Player = players[i]
			var pl_node: PlayerUI = get_node_or_null(NodePath(pl.name()))
			if pl_node == null:
				pl_node = player_scene.instantiate()
				pl_node.name = pl.name()
				if get_child_count() > 0:
					var my_sep = get_parent().get_node("Separator").duplicate()
					my_sep.custom_minimum_size.y /= 2
					add_child(my_sep)
				add_child(pl_node)
			pl_node.on_game_state_update(pl, i, max_score, max_energy)
