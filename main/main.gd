extends Node3D
class_name Main

func _ready() -> void:
	_setup_debug_fps()
	_setup_console()
	_setup_fullscreen()
	# Start the game manager thread (after all inner scenes have been initialized and are ready!)
	GameManager.start(Settings.game_paths())

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		GameManager.stop()

func _setup_debug_fps():
	# Move to the left side to avoid conflicts with our main UI
	var debug_fps_ui: Control = DebugMenu.get_child(0)
	debug_fps_ui.set_anchors_preset(Control.LayoutPreset.PRESET_TOP_LEFT)
	debug_fps_ui.position.x = 8
	var vbox = debug_fps_ui.get_child(0)
	vbox.set_anchors_preset(Control.LayoutPreset.PRESET_TOP_LEFT)
	vbox.position.x = 0
	for c in debug_fps_ui.get_child(0).get_children():
		if c is Label:
			c.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if c is BoxContainer:
			c.alignment = BoxContainer.ALIGNMENT_BEGIN
		if c is GridContainer:
			c.size_flags_horizontal = 0
	# Auto-show on debug builds
	if OS.is_debug_build():
		DebugMenu.style = DebugMenu.Style.VISIBLE_DETAILED

func _setup_console():
	LimboConsole.register_command(_cmd_debug_draw, "debug_draw", "Change debug draw mode (see Viewport.DebugDraw enum, 0 to disable)")
	LimboConsole.show_console()
	Log.d("Press " + str(InputMap.action_get_events("limbo_console_toggle").map(func(ev: InputEvent): return ev.as_text())) + " to toggle this console")
	# Auto-hide console after initial load
	var listener: Array = []
	listener.append(func(_state, _turn, phase): 
		if phase == SignalBusStatic.GAME_STATE_PHASE_ANIMATE: 
			LimboConsole.hide_console()
			SignalBus.game_state.disconnect(listener[0]))
	SignalBus.game_state.connect(listener[0])

func _cmd_debug_draw(debug_draw: int):
	get_viewport().debug_draw = debug_draw as Viewport.DebugDraw

func _setup_fullscreen():
	Log.d("Press " + str(InputMap.action_get_events("fullscreen").map(func(ev: InputEvent): return ev.as_text())) + " to toggle fullscreen")

func _input(event: InputEvent) -> void:
	if event.is_action_released("fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED: 
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED) 
