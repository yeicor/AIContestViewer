extends VBoxContainer
class_name PlayerUI

func _ready() -> void:
	$EnergyBar.modulate = Color(0.8, 0.8, 0.8)

func on_game_state_update(player: Player, color: Color, accum_score: int, max_score: int, max_energy: int):
	modulate = color
	$PlayerNameBar/MarginContainer/PlayerName.text = player.name()
	$ScoreBar.set_value(accum_score, max_score, player.score())
	$EnergyBar.set_value(player.energy(), max_energy)
