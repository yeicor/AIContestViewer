extends Node3D
class_name Main

func _ready() -> void:
	# Open the console during initial load
	LimboConsole.show_console()
	Log.d("Press " + str(InputMap.action_get_events("limbo_console_toggle").map(func(ev: InputEvent): return ev.as_text())) + " to toggle this console")
	# Start the game manager thread
	GameManager.start.call_deferred()
	# Use the global signal Event Bus to connect to some events
	SignalBus.game_state.connect(func(): LimboConsole.hide_console(), CONNECT_ONE_SHOT)
