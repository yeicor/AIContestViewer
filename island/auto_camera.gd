class_name GameAutoCamera3D
extends Node3D

var cell_count := Vector2i(-1, -1)
func _ready() -> void:
	if Settings.camera_mode_auto():
		SignalBus.game_state.connect(self._on_game_state)
	else:
		var stack = [self]  # Stack to process nodes
		# Collect all nodes in a depth-first manner
		var nodes = []
		while stack.size() > 0:
			var node = stack.pop_back()
			nodes.append(node)
			stack.append_array(node.get_children())  # Add children to stack
		# Free nodes in reverse order (leaves first)
		nodes.reverse()
		for node in nodes:
			node.queue_free()

@onready var players := $%Players
@onready var lighthouses := $%Lighthouses
@onready var camera_3d := $Camera3D
@onready var phantom_camera := $PhantomCamera
@onready var camera_target_pos := $CameraTargetPos
func _on_game_state(state: GameState, turn: int, phase: int):
	if phase == SignalBus.GAME_STATE_PHASE_INIT:
		if turn == 0:
			cell_count = state.island().size()
			self.apply_pos(camera_3d, 0.0)
		elif turn == 1: # TODO: 0? (order of operations... have to use state data instead which is more current!)
			self.reset_look_at_players()
		elif Settings.camera_auto_include_owned():
			self.reset_look_at_players()
			for lighthouse in lighthouses.get_children():
				if lighthouse.color != LighthouseScene.unowned_color:
					phantom_camera.append_look_at_target(lighthouse)

func reset_look_at_players():
	var _players: Array[Node3D] = []
	_players.assign(players.get_children())
	phantom_camera.set_look_at_targets(_players)


var _my_time_offset := 0.0
func _process(delta: float) -> void:
	self.apply_pos(camera_target_pos, self._my_time_offset)
	self._my_time_offset += delta

func apply_pos(cam: Node3D, time: float):
	var rot_angle := PI / 2 + Settings.camera_auto_rot_speed() * time
	# Slowly rotate by updating position adding some action to the scene
	var dir := Vector3(0, 1, 0).rotated(Vector3(1,0,0), deg_to_rad(270 - Settings.camera_auto_pitch()))\
	.rotated(Vector3(0, 1, 0), rot_angle)
	# TODO: Adjust zoom to show every relevant object in frame!
	var zoom := cell_count.distance_to(Vector2i.ZERO) * Settings.terrain_cell_side() / 1.8
	phantom_camera.look_at_offset = Vector3(dir.x, 0, dir.z) * zoom / 2.5 # Help camera look at everything
	cam.position = zoom * dir
	
