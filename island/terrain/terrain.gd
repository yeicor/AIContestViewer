@tool
class_name Terrain
extends MeshInstance3D

## TerrainTool organizes the code to be able to generate islands on demand and even test them in the editor.

@export var _click_to_regenerate: bool = false:
	set(new_val):
		if Engine.is_editor_hint():
			_regenerate()

@export var my_seed: int = 42:
	set(new_seed):
		my_seed = new_seed
		if Engine.is_editor_hint():
			_regenerate()



func _regenerate(): # Ignoring errors as this is an internal tool
	print("Regenerating mesh with seed: " + str(my_seed))
	var game_reader: GameReader  = GameReader.open(ConfigClass.DEFAULT_GAME_PATH)
	var first_round: GameState   = game_reader.parse_next_state()
	var island: GameState.Island = first_round.island(false)
	var heightmap: Array = DiamondSquare.generate_heightmap(island._grid, my_seed)
	mesh = MeshGen.from_heightmap(heightmap)

