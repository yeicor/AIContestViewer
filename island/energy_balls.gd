@tool
extends Node3D

var energyBallScene := preload("res://island/player/lightning/lightning_sphere.tscn")

func _on_terrain_terrain_ready(_mi: MeshInstance3D, game: GameState) -> void:
	get_children().map(func(c): remove_child(c))
	# TODO: May need particles and shaders for fast generation through simple texture edits...
	var island_meta := game.island()
	for z in island_meta.height():
		for x in island_meta.width():
			var energy := island_meta.energy_at(x, z)
			for i in range(energy):
				var loc_offset := Vector2(0.5, 0.5)
				if energy > 1: # Arrange energy balls to see them all
					var angle := 2 * PI * i / energy
					loc_offset.x += 0.25 * cos(angle)
					loc_offset.y += 0.25 * sin(angle)
				var location = IslandH.hit_pos_at_cell(Vector2(x, z) + loc_offset)
				var inst: Node3D = energyBallScene.instantiate()
				inst.global_position = location
				add_child(inst)
