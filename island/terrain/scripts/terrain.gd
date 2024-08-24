@tool
class_name Terrain
extends Node3D

## TerrainTool organizes the code to be able to generate islands on demand and even test them in the editor.

@warning_ignore("unused_private_class_variable")
@export var _do_regenerate: bool = false:
	set(new_val):
		if Engine.is_editor_hint() and is_node_ready():
			_regenerate_demo()

@export var my_seed: int = 42:
	set(new_seed):
		my_seed = new_seed
		if Engine.is_editor_hint() and is_node_ready():
			_regenerate_demo()

@export var vertex_count: float = 100000:
	set(new_vertex_count):
		vertex_count = new_vertex_count
		if Engine.is_editor_hint() and is_node_ready():
			_regenerate_demo()


@export var cell_side: float = 10:
	set(new_cell_side):
		cell_side = new_cell_side
		if Engine.is_editor_hint() and is_node_ready():
			_regenerate_demo()

@export var steepness: float = 1: # 1 -> 45º
	set(new_steepness):
		steepness = new_steepness
		if Engine.is_editor_hint() and is_node_ready():
			_regenerate_demo()

func _ready():
	if not Engine.is_editor_hint():
		my_seed = Settings.common_seed()
		vertex_count = Settings.terrain_vertex_count()
		cell_side = Settings.terrain_cell_side()
		steepness = Settings.terrain_max_steepness()
		_regenerate_demo()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if _generate_thread != null && _generate_thread.is_alive():
			_generate_thread.wait_to_finish()

var _last_regeneration_frame: int = -1
func _regenerate_demo():
	if _last_regeneration_frame == Engine.get_frames_drawn():
		return # Ignore multiple request on the same frame like while setting all properties at start.
	_last_regeneration_frame = Engine.get_frames_drawn()
	print("_regenerate_demo ", my_seed, " ", cell_side, " ", steepness)
	var game_reader: GameReader = Settings.game_reader()
	var first_round: GameState  = game_reader.parse_next_state()
	generate(first_round)

var _generate_thread: Thread = null

func _exit_tree():
	if _generate_thread != null && _generate_thread.is_started():
		_generate_thread.wait_to_finish() # Should already be called.

func generate(game: GameState):
	if _generate_thread == null:
		_generate_thread = Thread.new()
	if _generate_thread.is_alive():
		print("Note: ignoring generate() while another generate() is running in a separate thread")
		return
	var start_time: float = Time.get_ticks_msec()
	var heightmap := $HeightMap
	_generate_thread.start(func():
		var hmesh: Mesh = heightmap.generate(game, my_seed, cell_side, steepness, vertex_count)
		(func():
			var meshNode = MeshInstance3D.new()
			meshNode.mesh = hmesh
			meshNode.material_override = preload("res://island/terrain/material.tres")
			add_child(meshNode)
			print("[TIMING] Terrain: Fully generated base heightmap mesh in " + str(Time.get_ticks_msec() - start_time) + "ms")
			_generate_thread.wait_to_finish()).call_deferred())
