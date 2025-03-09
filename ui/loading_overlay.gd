extends PanelContainer

func _ready() -> void:
	SignalBus.game_state.connect(func (_state, turn, phase):
		if turn == 0: # Terrain is re-generated on each initial turn, and it is a slow process
			if phase == SignalBus.GAME_STATE_PHASE_INIT:
				LimboConsole.show_console()
				visible = true
			elif phase == SignalBus.GAME_STATE_PHASE_ANIMATE:
				LimboConsole.hide_console()
				visible = false)
