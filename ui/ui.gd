class_name UI
extends Control

static var _instance: Control = null

@warning_ignore("unused_private_class_variable")
@onready var _game_area: Control = $"%GameArea"

func _ready() -> void:
	if _instance != null:
		SLog.sw("There should only be one UI instance! Here be dragons!")
	_instance = self
	SignalBus.game_state.connect(func (_state, turn, phase):
		if turn == 0: # Terrain is re-generated on each initial turn, and it is a slow process
			if phase == SignalBus.GAME_STATE_PHASE_INIT:
				LimboConsole.show_console()
				$LoadingUI.visible = true
				$GameUI.visible = false
			elif phase == SignalBus.GAME_STATE_PHASE_ANIMATE:
				LimboConsole.hide_console()
				$LoadingUI.visible = false
				$GameUI.visible = true)

static func distance_to_game_area(world: Vector3) -> float:
	if _instance == null:
		SLog.sw("distance_to_game_area: _instance not ready!")
		return -1.0
	
	var viewport := _instance.get_viewport()
	var camera := viewport.get_camera_3d()
	if not camera:
		SLog.sw("distance_to_game_area: camera_3d not set!")
		return -1.0 # Retorna un valor inválido si no hay cámara
	
	var screen_pos := camera.unproject_position(world)
	var area = _instance._game_area.get_global_rect()
	var diff_2d := Vector2(
		max(area.position.x - screen_pos.x, screen_pos.x - area.end.x),
		max(area.position.y - screen_pos.y, screen_pos.y - area.end.y))
	var is_out_corner := diff_2d.x > 0 && diff_2d.y > 0
	if is_out_corner:
		return diff_2d.length()
	else:
		var dist: float = max(diff_2d.x, diff_2d.y)
		if dist > 0: # Outside
			return dist
		else: # Inside
			return diff_2d.length()
