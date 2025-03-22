class_name GameAutoCamera3D
extends Node3D

@onready var camera_3d := $Camera3D
@onready var phantom_camera := $PhantomCamera
@onready var camera_target_pos := $CameraTargetPos
@onready var camera_target_look_at := $CameraTargetLookAt

var _my_time_offset := 0.0
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

func _on_terrain_terrain_ready(_mi: MeshInstance3D, state: GameState) -> void:
	# Wait for terrain and auto-snap in place for turn 0
	cur_zoom = IslandH.num_cells().distance_to(Vector2i.ZERO) * Settings.terrain_cell_side() / 3.0
	max_zoom_out = IslandH.num_cells().distance_to(Vector2i.ZERO) * Settings.terrain_cell_side() / 1.5
	self.recompute_pos(camera_3d, 0.0)
	recompute_lookAt(state)
	camera_3d.look_at(camera_target_look_at.position)
	self._my_time_offset = 0.01

func _on_game_state(state: GameState, turn: int, phase: int):
	if turn == 0:
		if phase == SignalBus.GAME_STATE_PHASE_ANIMATE:
			$Camera3D.current = true
	else:
		if phase == SignalBus.GAME_STATE_PHASE_INIT:
			recompute_lookAt(state)
			phantom_camera.look_at_damping = true # FIXME: Only enable after snapping into place (avoid first jump!)

func _process(delta: float) -> void:
	if self._my_time_offset > 0.0: # Wait to be enabled
		self.recompute_pos(camera_target_pos, self._my_time_offset)
		self._my_time_offset += delta

var cur_zoom := 100.0 
var max_zoom_out := 100.0 
func recompute_pos(cam: Node3D, time: float):
	# Drone-like view of the game
	var rot_angle := PI / 2 + Settings.camera_auto_rot_speed() * time
	# Slowly rotate by updating position adding some action to the scene
	var dir := Vector3(0, 1, 0).rotated(Vector3(1,0,0), deg_to_rad(270 - Settings.camera_auto_pitch()))\
	.rotated(Vector3(0, 1, 0), rot_angle)
	# TODO: Adjust zoom to show every relevant object in frame! UI.distance_to_game_area()!
	var zoom_anim = smoothstep(0.0, 10.0, time)
	var zoom = (1.0 - zoom_anim) * cur_zoom + zoom_anim * max_zoom_out
	phantom_camera.look_at_offset = Vector3(dir.x, 0, dir.z) * zoom / 2.5 # Help camera look at everything
	cam.position = zoom * dir

func recompute_lookAt(state: GameState):
	# Look at targets (predict currently animating turn locations, smooth)
	var wanted_look_at_pos = Vector3.ZERO
	var wanted_look_at_pos_count := 0
	for p in state.players():
		wanted_look_at_pos += IslandH.hit_pos_at_cell(Vector2(p.pos()) + Vector2.ONE * 0.5)
		wanted_look_at_pos_count += 1
	if Settings.camera_auto_include_owned():
		for lh in state.lighthouses():
			if lh.owner() >= 0:
				wanted_look_at_pos += IslandH.hit_pos_at_cell(Vector2(lh.pos()) + Vector2.ONE * 0.5)
				wanted_look_at_pos_count += 1
	if wanted_look_at_pos_count > 0:
		camera_target_look_at.position = wanted_look_at_pos / wanted_look_at_pos_count
