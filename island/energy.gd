@tool
extends Node3D

var energy_img: Image
func _on_terrain_terrain_ready(_mi: MeshInstance3D, game: GameState) -> void:
	GameManager.pause() # Lock the game timer while generating
	var start_time := Time.get_ticks_msec()
	var img_with_corners := Settings.island_water_level_distance_image()
	@warning_ignore("integer_division")
	energy_img = Image.create_empty((img_with_corners.get_width()-1)/2, (img_with_corners.get_height()-1)/2, false, Image.FORMAT_R8)
	Settings.island_energymap_set(ImageTexture.create_from_image(energy_img))
	_on_game_state(game, -1, SignalBusStatic.GAME_STATE_PHASE_INIT) # Reuse code
	if not SignalBus.game_state.is_connected(_on_game_state):
		SignalBus.game_state.connect(_on_game_state)
	SLog.sd("[timing] Energy setup in " + str(Time.get_ticks_msec() - start_time) + "ms")
	GameManager.resume()
	
func _on_game_state(state: GameState, _turn: int, phase: int):
	# There are nicer looking alternatives, but this should be faster...
	if phase == SignalBusStatic.GAME_STATE_PHASE_INIT:
		var island_meta := state.island()
		for z in island_meta.height():
			for x in island_meta.width():
				var energy := island_meta.energy_at(x, z)
				energy_img.set_pixel(x, z, float(energy) / 100.0 * Color.WHITE)
		(Settings.island_energymap() as ImageTexture).update(energy_img)
	
