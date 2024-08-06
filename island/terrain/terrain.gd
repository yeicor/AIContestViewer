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

@export var cell_side: float = 10:
	set(new_cell_side):
		cell_side = new_cell_side
		if Engine.is_editor_hint():
			_regenerate_demo()

@export var steepness: float = 1: # 1 -> 45º
	set(new_steepness):
		steepness = new_steepness
		if Engine.is_editor_hint():
			_regenerate_demo()
			


func _regenerate_demo(): # Ignoring errors as this is an internal tool
	var game_reader: GameReader  = GameReader.open(ConfigClass.DEFAULT_GAME_PATH)
	var first_round: GameState   = game_reader.parse_next_state()
	var island: Island = first_round.island(false)
	generate(island)


func generate(island: Island):
	var heightmap_info: Array = await $HeightMapGen.generate_heightmap(island, my_seed)
	var heightmap: Array = heightmap_info[0]
	var heightmap_samples: Vector2 = heightmap_info[1]
	var sample_factor: Vector2 = Vector2(island.size()) / heightmap_samples 
	mesh = MeshGen.from_heightmap(heightmap, Vector3(cell_side, steepness, cell_side) * 
		Vector3(sample_factor.x, cell_side, sample_factor.y))

