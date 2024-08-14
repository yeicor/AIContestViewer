@tool
class_name Terrain
extends MeshInstance3D

## TerrainTool organizes the code to be able to generate islands on demand and even test them in the editor.

@warning_ignore("unused_private_class_variable")
@export var _click_to_regenerate: bool = false:
	set(new_val):
		if Engine.is_editor_hint():
			_regenerate_demo()

@export var my_seed: int = 42:
	set(new_seed):
		my_seed = new_seed
		if Engine.is_editor_hint():
			_regenerate_demo()


@export var cell_side: float = 10.0:
	set(new_cell_side):
		cell_side = new_cell_side
		if Engine.is_editor_hint():
			_regenerate_demo()

@export var steepness: float = 1: # 1 -> 45º
	set(new_steepness):
		steepness = new_steepness
		if Engine.is_editor_hint():
			_regenerate_demo()

func _ready():
	if not Engine.is_editor_hint():
		_regenerate_demo()

func _regenerate_demo(): # Ignoring errors as this is an internal tool
	print("_regenerate_demo ", my_seed, " ", cell_side, " ", steepness)
	var game_reader: GameReader = Setting.game_reader()
	var first_round: GameState   = game_reader.parse_next_state()
	generate(first_round)


func generate(game: GameState):
	var heightmap_info    : Array = await $HeightMapGen.generate_heightmap(game, my_seed)
	var heightmap         : Array = heightmap_info[0]
	var heightmap_samples : Vector2 = heightmap_info[1]
	var xz_step           := Vector2(cell_side, cell_side) * Vector2(game.island().size()) / heightmap_samples
	var y_step            := steepness * cell_side / 2
	# heightmap = [heightmap[0]] # Fast CPU side for testing!
	mesh = MeshGen.from_heightmap(heightmap, Vector3(xz_step.x, y_step, xz_step.y))

