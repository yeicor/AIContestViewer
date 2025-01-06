extends VBoxContainer
class_name PlayerUI

func _ready() -> void:
	$EnergyBar.modulate = Color(0.8, 0.8, 0.8)

func on_game_state_update(player: Player, player_index: int, max_score: int, max_energy: int):
	modulate = ColorGenerator.get_color(player_index)
	$PlayerNameBar/MarginContainer/PlayerName.text = player.name()
	$ScoreBar.set_value(player.score(), max_score)
	$EnergyBar.set_value(player.energy(), max_energy)
