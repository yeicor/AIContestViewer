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


## Returns <1 if inside the camera game area, 1 at any of the edges/corners and >1 if outside!
static func distance_to_game_area(world: Vector3) -> float:
	if _instance == null:
		SLog.sw("distance_to_game_area: _instance not ready!")
		return -1.0
	
	var viewport := _instance.get_viewport()
	var camera := viewport.get_camera_3d()
	if not camera:
		SLog.sw("distance_to_game_area: camera_3d not set!")
		return -1.0
	
	var screen_pos := camera.unproject_position(world)
	var area: Rect2 = _instance._game_area.get_global_rect()
	var res := ((screen_pos - area.get_center()) / (area.size / 2)).length()
	#print("AREA: ", area, "\t| SCREEN: ", screen_pos, "\t| RES: ", res)
	return res

static func projected_game_area_center_offset(depth: float) -> Vector3:
	if _instance == null:
		SLog.sw("distance_to_game_area: _instance not ready!")
		return Vector3.ZERO
	
	var viewport := _instance.get_viewport()
	var camera := viewport.get_camera_3d()
	if not camera:
		SLog.sw("distance_to_game_area: camera_3d not set!")
		return Vector3.ZERO
		
	var game_center = camera.project_position(_instance._game_area.get_global_rect().get_center(), depth)
	var cam_center = camera.project_position(viewport.get_visible_rect().get_center(), depth)
	return (cam_center - game_center) / 2
	
