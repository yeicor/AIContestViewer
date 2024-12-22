extends Node3D
class_name Main

func _ready() -> void:
	# Open the console during initial load
	_setup_console()
	# Use the global signal Event Bus to connect to some events
	var listener: Array = []
	listener.append(func(_state, _turn, phase): 
		if phase == SignalBusStatic.GAME_STATE_PHASE_ANIMATE: 
			LimboConsole.hide_console()
			SignalBus.game_state.disconnect(listener[0]))
	SignalBus.game_state.connect(listener[0])
	# Start the game manager thread (after all inner scenes have been initialized and are ready!)
	GameManager.start()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		GameManager.stop()

func _setup_console():
	LimboConsole.register_command(_cmd_debug_draw, "debug_draw", "Change debug draw mode (see Viewport.DebugDraw enum, 0 to disable)")
	LimboConsole.show_console()
	Log.d("Press " + str(InputMap.action_get_events("limbo_console_toggle").map(func(ev: InputEvent): return ev.as_text())) + " to toggle this console")

func _cmd_debug_draw(debug_draw: int):
	get_viewport().debug_draw = debug_draw as Viewport.DebugDraw
