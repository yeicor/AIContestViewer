@tool
class_name Terrain
extends Node3D

## TerrainTool organizes the code to be able to generate islands on demand and even test them in the editor.
signal terrain_ready(mi: MeshInstance3D, game: GameState, cached: bool)

func clean():
	for child in get_children():
		if child.name.begins_with("_TerrainGen"):
			child.queue_free()

@warning_ignore("unused_private_class_variable")
@export var generate_in_editor: bool = false:
	set(new_val):
		if Engine.is_editor_hint() and is_node_ready():
			clean()
			_regenerate_demo()

@export var my_seed: int = 42:
	set(new_seed):
		my_seed = new_seed
		if generate_in_editor and Engine.is_editor_hint() and is_node_ready():
			clean()
			_regenerate_demo()

@export var vertex_count: float = 100000:
	set(new_vertex_count):
		vertex_count = new_vertex_count
		if generate_in_editor and Engine.is_editor_hint() and is_node_ready():
			clean()
			_regenerate_demo()

@export var cell_side: float = 10:
	set(new_cell_side):
		cell_side = new_cell_side
		if generate_in_editor and Engine.is_editor_hint() and is_node_ready():
			clean()
			_regenerate_demo()

@export var steepness: float = 1: # 1 -> 45º
	set(new_steepness):
		steepness = new_steepness
		if generate_in_editor and Engine.is_editor_hint() and is_node_ready():
			clean()
			_regenerate_demo()

var material = preload("res://island/terrain/material.tres")
func _ready():
	if not Engine.is_editor_hint():
		material.shader.code = Settings.as_defines() + material.shader.code
		my_seed = Settings.common_seed()
		vertex_count = Settings.terrain_vertex_count()
		cell_side = Settings.terrain_cell_side()
		steepness = Settings.terrain_max_steepness()
		# Prepare to generate as soon as a new game round starts
		if not SignalBus.game_state.is_connected(_on_game_state):
			SignalBus.game_state.connect(_on_game_state)

var _last_regeneration_frame: int = -1234
func _regenerate_demo():
	if _last_regeneration_frame == Engine.get_frames_drawn():
		return # Ignore multiple request on the same frame like while setting all properties at start.
	_last_regeneration_frame = Engine.get_frames_drawn()
	var game_reader: GameReader = GameReader.open("res://testdata/small_map_10k_rounds.jsonl.gz")
	var first_round: GameState  = game_reader.parse_next_state()
	generate(first_round)

var _last_built_island_id: String
func _on_game_state(state: GameState, turn: int, phase: int):
	# Regenerate terrain for each new game we find (it is likely to have a new map)
	if turn == 0 and phase == SignalBus.GAME_STATE_PHASE_INIT:
		# Lock the game timer while generating
		if _last_built_island_id != state.island().to_ascii_string():
			_last_built_island_id = state.island().to_ascii_string()
			GameManager.pause()
			terrain_ready.connect(func(_mi, _game, _cached): 
				GameManager.resume(), CONNECT_ONE_SHOT)
			# Remove any previous MeshInstance3D child and create a new one
			get_children().map(func (x): if (x is MeshInstance3D): remove_child(x))
			generate(state)
		else:
			SLog.sd("Reusing previous terrain, as the Island did not change!")
			terrain_ready.emit(get_child(get_child_count() - 1), state, true) # Cached!

var _generate_thread: Thread = null

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		pass
		#if _generate_thread != null && _generate_thread.is_alive():
			#_generate_thread.wait_to_finish()

func generate(game: GameState):
	assert(vertex_count >= 0)
	assert(steepness > 0.0)
	if not has_node("HeightMap"):
		SLog.sw("Note: ignoring generate() before HeightMap node exists...")
		return
	if _generate_thread == null:
		_generate_thread = Thread.new()
	elif _generate_thread.is_started():
		if _generate_thread.is_alive():
			SLog.sw("Note: waiting for previous terrain generation to complete before starting another one...")
		_generate_thread.wait_to_finish()
	var start_time: float = Time.get_ticks_msec()
	var heightmap := $HeightMap
	_generate_thread.start(func():
		var hmesh: Mesh = heightmap.generate(game, my_seed, cell_side, steepness, vertex_count)
		(func():
			_generate_thread.wait_to_finish()
			var meshNode = MeshInstance3D.new()
			meshNode.name = "_TerrainGen" + str(Time.get_ticks_usec())
			meshNode.mesh = hmesh
			var mat = material.duplicate()
			mat.set_shader_parameter("bb_half", meshNode.get_aabb().end)
			mat.next_pass.set_shader_parameter("bb_half", meshNode.get_aabb().end)
			hmesh.surface_set_material(0, mat)
			add_child(meshNode)
			SLog.sd("[TIMING] Terrain: Fully generated base heightmap mesh in " + str(Time.get_ticks_msec() - start_time) + "ms")
			terrain_ready.emit(meshNode, game, false)).call_deferred())
