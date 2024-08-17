extends Node3D

func _ready() -> void:
	pass
	
	#
	#var game_reader: GameReader = Setting.game_reader()
	#if game_reader == null:
		#print("Failed to create game reader")
	#var first_round: GameState = game_reader.parse_next_round()
	#if first_round == null:
		#print("Failed to parse round / EOF")
		#return
	#for player: Player in first_round.players():
		#print(player.to_ascii_string())
	#var island: Island = first_round.island(false)
	#print(island.to_ascii_string())
	#for lh: Lighthouse in first_round.lighthouses():
		#print(lh.to_ascii_string())
	#for conn: Connection in first_round.connections():
		#print(conn.to_ascii_string())
		#
	#print(GameState.array_2d_to_ascii_string(island.distance_to_water_level()
		#.map(func(row): return row.map(func(x): return str(x)))))
	
