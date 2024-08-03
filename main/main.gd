extends Node3D

func _ready() -> void:
	var game_reader: GameReader = GameReader.open(Config.game_path())
	if game_reader == null:
		print("Failed to create game reader")

	var first_round: GameState = game_reader.parse_next_round()
	if first_round == null:
		print("Failed to parse round / EOF")
		return

	var island: GameState.Island = first_round.island(false)
	print(island.to_ascii_string())
	for lh: GameState.Lighthouse in first_round.lighthouses():
		print(lh.to_ascii_string())
	for conn: GameState.Connection in first_round.connections():
		print(conn.to_ascii_string())
		
	var mesh: Mesh = MeshGen.from_heightmap(island._grid, Vector2.ZERO, 20.0, 0.0)
	$"World/TerrainTmp".mesh = mesh
	
