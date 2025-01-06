extends PanelContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var label_pre = get_meta("label_pre")
	$MarginContainer/HBoxContainer/LabelPre.text = label_pre
	var font_size = get_meta("font_size")
	for label in $MarginContainer/HBoxContainer.get_children():
		label.label_settings = label.label_settings.duplicate()
		label.label_settings.font_size = font_size
		if label.name.contains("PerTurn"):
			label.label_settings.font_size *= 0.8

var _last_value = 0

@onready var pg := $Progress
@onready var value_label := $MarginContainer/HBoxContainer/Value
@onready var value_per_turn_label := $MarginContainer/HBoxContainer/ValuePerTurn

func set_value(cur: float, max_others: float):
	pg.value = _get_exponential_progress_auto(cur, max_others)
	#SLog.sd("PB value: " + str(cur) + " / " + str(max_others) + " -> " + str(pg.value))
	value_label.text = TopBar.pretty_print_number(cur)
	value_per_turn_label.text = TopBar.pretty_print_number(cur - _last_value)
	_last_value = cur


func _get_exponential_progress_auto(value: float, max_value: float) -> float:
	"""
	Calculates progress from 0 to 1 using an exponential scale with an auto-computed exponent.
	The scaling is adjusted to ensure values are more discernible and skew towards 1 for higher values.
	
	Parameters:
	- value: The input value (>= 0) to map.
	- min_value: The minimum reference value (>= 0).
	- max_value: The maximum reference value (> min_value).
	
	Returns:
	- A float between 0 and 1 representing progress.
	"""
	# Compute the logarithmic ratio as a heuristic
	var exponent = 1.0 / max(1.0, log(max_value)/log(100))

	# Normalize the value to a range of [0, 1]
	var normalized_value = clamp(value, 0, max_value) / max_value

	# Apply exponential scaling with the adjusted exponent
	var progress = pow(normalized_value, exponent)

	return progress
