extends PanelContainer

func _ready() -> void:
	var callable = []
	callable.append(func (_state, turn, phase):
		if turn == 0 && phase == SignalBus.GAME_STATE_PHASE_ANIMATE:
			visible = false
			SignalBus.game_state.disconnect(callable[0]))
	SignalBus.game_state.connect(callable[0])
