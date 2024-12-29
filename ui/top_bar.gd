extends PanelContainer

@onready var turn_label := $MarginContainer/HBoxContainer/TurnLabel

func _ready() -> void:
	SignalBus.game_state.connect(self._on_game_state)

var _last_turn = -1
func _on_game_state(_state: GameState, turn: int, _phase: int):
	if turn != _last_turn:
		turn_label.text = str(turn)
		if Settings.common_turn_count() > 0:
			var progress := clampf(float(turn) / float(Settings.common_turn_count()), 0, 1)
			(self.material as ShaderMaterial).set_shader_parameter("progress", progress)
		_last_turn = turn
