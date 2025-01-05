extends PanelContainer

@onready var turn_label := $MarginContainer/HBoxContainer/TurnLabel

func _ready() -> void:
	SignalBus.game_state.connect(self._on_game_state)

func _on_game_state(_state: GameState, turn: int, phase: int):
	if phase == SignalBus.GAME_STATE_PHASE_INIT:
		turn_label.text = pretty_print_number(turn)
		if Settings.common_turn_count() > 0:
			var progress := float(turn % Settings.common_turn_count()) / float(Settings.common_turn_count())
			(self.material as ShaderMaterial).set_shader_parameter("progress", progress)


static func pretty_print_number(value: float, significant_digits: int = 3) -> String:
	var suffixes = ["", "K", "M", "G", "T", "P", "E"]
	var index = 0

	while abs(value) >= 1000 and index < suffixes.size() - 1:
		value /= 1000
		index += 1
		
	# Determine the number of decimal places based on significant digits
	var magnitude = floor(log(abs(value))/log(10)) if value != 0 else 0
	var num_decimals = max(0, significant_digits - 1 - int(magnitude))

	# Format the number with the calculated number of decimals
	var formatted = "%.*f" % [num_decimals, value]

	# Remove unnecessary ".0" or ".00" if present
	if formatted.find(".") >= 0 and index == 0:
		formatted = formatted.rstrip("0").rstrip(".")

	return formatted + suffixes[index]
