extends PanelContainer
class_name TopBar

@onready var progress := $Progress
@onready var turn_label := $MarginContainer/HBoxContainer/TurnLabel

var _wants_to_pause := false
var _is_paused := false

func _ready() -> void:
	SignalBus.game_state.connect(self._on_game_state)
	$PauseButton.pressed.connect(func(): _on_pause_action())
	if Settings.common_start_paused(): _on_pause_action()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"): _on_pause_action()
	if event.is_action_pressed("step"): _on_pause_action(true)

func _on_pause_action(single_step: bool = false):
	if not _is_paused:
		_wants_to_pause = true # Will have effect at the end of the turn
	else:
		GameManager.resume()
		_is_paused = false
		if not single_step:
			_wants_to_pause = false

func _on_game_state(_state: GameState, turn: int, phase: int):
	if phase == SignalBus.GAME_STATE_PHASE_INIT:
		turn_label.text = pretty_print_number(turn)
	
	if phase == SignalBus.GAME_STATE_PHASE_END:
		if _wants_to_pause:
			if not _is_paused:
				GameManager.pause()
				_is_paused = true

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
