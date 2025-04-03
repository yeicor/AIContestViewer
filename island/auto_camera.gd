class_name GameAutoCamera3D
extends Node3D

@onready var camera_3d := $Camera3D
@onready var phantom_camera := $PhantomCamera3D
@onready var camera_target_pos := $CameraTargetPos
@onready var camera_target_look_at := $CameraTargetLookAt

var _my_time_offset := 0.0
var _keypoints: Array[Vector3] = [] # Locations that the camera should keep in frame at all times.
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

func _on_terrain_terrain_ready(_mi: MeshInstance3D, state: GameState, _cached: bool) -> void:
	GameManager.pause()
	# Wait for terrain and auto-snap in place for turn 0
	cur_dist = IslandH.num_cells().distance_to(Vector2i.ZERO) * Settings.terrain_cell_side() / 3.0
	recompute_lookAt_info(state)
	self._my_time_offset = 0.0
	self.recompute_look_at()
	self.recompute_pos(camera_target_pos, 0.0, 0.1)
	camera_3d.look_at_from_position(camera_target_pos.global_position, camera_target_look_at.global_position)
	var sum := func(accum, number): return accum + number
	camera_target_look_at.global_position = _keypoints.reduce(sum, Vector3.ZERO) / _keypoints.size()
	GameManager.resume()

func _on_game_state(state: GameState, turn: int, phase: int):
	if turn == 0:
		if phase == SignalBus.GAME_STATE_PHASE_ANIMATE:
			$Camera3D.environment = get_viewport().get_camera_3d().environment
			$Camera3D.current = true
	else:
		if phase == SignalBus.GAME_STATE_PHASE_INIT:
			recompute_lookAt_info(state)
	if phase == SignalBus.GAME_STATE_PHASE_END_ROUND:
		_keypoints.clear() # Stop moving while showing the podium

func _process(delta: float) -> void:
	if not _keypoints.is_empty(): # Wait to be enabled
		self.recompute_look_at()
		self.recompute_pos(camera_target_pos, self._my_time_offset, delta)
		if self._my_time_offset > 0.0: # Avoid initial "tween"
			phantom_camera.look_at_damping = true
			phantom_camera.follow_damping = true
		self._my_time_offset += delta

var cur_dist := 100.0
func recompute_pos(cam: Node3D, time: float, delta: float):
	# Drone-like view of the game
	var rot_angle := PI / 2 + Settings.camera_auto_rot_speed() * time
	# Slowly rotate by updating position adding some action to the scene
	var dir := Vector3(0, 1, 0).rotated(Vector3(1,0,0), deg_to_rad(270 - Settings.camera_auto_pitch()))\
	.rotated(Vector3(0, 1, 0), rot_angle)
	var wanted_dist_delta := -1.0
	for p in _keypoints: # Displace the look at offset to ensure correct centering according to UI!
		wanted_dist_delta = max(wanted_dist_delta, UI.distance_to_game_area(p) - 1.0)
	# Zoom much faster at the start (converge instantly)
	var wanted_dist_delta_scale = 500 - 475 * smoothstep(0, Settings.common_start_turn_secs(), time)
	wanted_dist_delta *= wanted_dist_delta_scale * delta
	#print("wanted_dist_delta:", wanted_dist_delta)
	cur_dist = cur_dist + wanted_dist_delta * Settings.terrain_cell_side()
	cur_dist = clampf(cur_dist, 4 * Settings.terrain_cell_side(), 
			IslandH.num_cells().length() * 1.25 * Settings.terrain_cell_side())
	cam.position = camera_target_look_at.position + cur_dist * dir
	# Help camera look at everything given the offset caused by the right UI panel
	phantom_camera.look_at_offset = UI.projected_game_area_center_offset(cur_dist)

func recompute_look_at():
	var sum := func(accum, number): return accum + number
	camera_target_look_at.position = _keypoints.reduce(sum, Vector3.ZERO) / _keypoints.size()
	# Push the Y position towards 0 if we are looking from far away.
	# This helps avoid looking too much at the sea on the top half of the screen.
	# Caused by height differences of terrain helping to look up too much
	camera_target_look_at.position.y *= 1 - smoothstep(0, IslandH.num_cells().length() * Settings.terrain_cell_side(), cur_dist)


func recompute_lookAt_info(state: GameState):
	# Look at targets (predict currently animating turn locations, smooth)
	_keypoints.clear()
	for p in state.players():
		_keypoints.push_back(IslandH.hit_pos_at_cell(Vector2(p.pos()) + Vector2.ONE * 0.5))
	if Settings.camera_auto_include_owned():
		for lh in state.lighthouses():
			if lh.owner() >= 0:
				_keypoints.push_back(IslandH.hit_pos_at_cell(Vector2(lh.pos()) + Vector2.ONE * 0.5))
