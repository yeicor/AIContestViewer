extends Node3D
class_name Main

func _ready() -> void:
	_setup_debug_fps()
	_setup_console()
	_setup_fullscreen()
	_setup_camera()
	_setup_rendering()
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

func _setup_rendering():
	viewport = get_viewport()
	if Settings.common_variable_rate_shading():
		viewport.vrs_texture = preload("res://main/variable_rate_shading_default.png")
		viewport.vrs_mode = Viewport.VRS_TEXTURE
		# Detect window resizes and force update for 1 frame
		get_window().connect("size_changed", func():
			viewport.vrs_update_mode = Viewport.VRS_UPDATE_ONCE)
	
	match(Settings.common_rendering_scale_mode()):
		"Bilinear": viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		"FSR": viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		"FSR2": viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		_: SLog.sw("Ignoring invalid rendering scale mode of " + 
		Settings.common_rendering_scale_mode() + ". Valid options are: Bilinear, FSR, FSR2.")
	
	if Settings.common_rendering_scale() > 0.0:
		viewport.scaling_3d_scale = Settings.common_rendering_scale()
	else: # Enable dynamic changes!
		viewport_rid = viewport.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
		target_fps = DisplayServer.screen_get_refresh_rate()
		if target_fps < 0: target_fps = 60
		last_change = Time.get_ticks_msec()

var current_fps: float
var target_fps: float
var viewport: Viewport
var viewport_rid: RID
var last_change: int

func _process(delta: float) -> void:
	_process_rendering(delta)

func _process_rendering(_delta: float) -> void:
	if viewport_rid != null:
		var frametime_cpu := RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.get_frame_setup_time_cpu()
		var frametime_gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
		
		var frame_time = max(frametime_cpu, frametime_gpu) / 1000.0
		var current_fps_instant = 1.0 / frame_time if frame_time > 0 else target_fps
		current_fps = current_fps * 0.9 + current_fps_instant * 0.1
		
		var wanted_scale := viewport.scaling_3d_scale
		
		if current_fps < target_fps * 0.9:
			wanted_scale = max(0.5, (roundi(wanted_scale * 100) - 5) / 100.0)
		elif current_fps > target_fps * 1.1:
			wanted_scale = min(1.0, (roundi(wanted_scale * 100) + 5) / 100.0)
		
		if wanted_scale != viewport.scaling_3d_scale:
			if Time.get_ticks_msec() - last_change > 3000:
				viewport.scaling_3d_scale = wanted_scale
				SLog.sd("Changing rendering scale dynamically to: " + 
				str(wanted_scale) + " - currently plausible FPS: " + 
				str(current_fps) + " - target FPS: " + str(target_fps))
				viewport.vrs_update_mode = Viewport.VRS_UPDATE_ONCE
				last_change = Time.get_ticks_msec()
