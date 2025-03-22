extends Node3D
class_name Main

func _ready() -> void:
	_setup_debug_fps()
	_setup_console()
	_setup_fullscreen()
	_setup_camera()
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

func _setup_camera():
	SignalBus.game_state.connect(func (state: GameState, turn, phase):
		if turn == 0: # Terrain is re-generated on each initial turn, and it is a slow process
			if phase == SignalBus.GAME_STATE_PHASE_INIT:
				if Settings.camera_mode_auto():
					$RTSCamera.current = true # Temporarily set this point of view
					$RTSCamera.look_at_from_position(Vector3(
						float(state.island().width()) / 2.0 * Settings.terrain_cell_side(), 100,
						float(state.island().height()) / 2.0 * Settings.terrain_cell_side()
					), Vector3.ZERO))
