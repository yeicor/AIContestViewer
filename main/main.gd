extends Node3D
class_name Main

func _ready() -> void:
	# Open the console during initial load
	_setup_console()
	# Start the game manager thread
	GameManager.start.call_deferred()
	# Use the global signal Event Bus to connect to some events
	SignalBus.game_state.connect(func(): LimboConsole.hide_console(), CONNECT_ONE_SHOT)


func _setup_console():
	LimboConsole.register_command(_cmd_debug_draw, "debug_draw", "Change debug draw mode (see Viewport.DebugDraw enum, 0 to disable)")
	LimboConsole.show_console()
	Log.d("Press " + str(InputMap.action_get_events("limbo_console_toggle").map(func(ev: InputEvent): return ev.as_text())) + " to toggle this console")

func _cmd_debug_draw(debug_draw: int):
	get_viewport().debug_draw = debug_draw as Viewport.DebugDraw
