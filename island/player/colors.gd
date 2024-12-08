@tool
extends EditorScript

class_name ColorGenerator

# Initialize variables
static var hue_levels: Array = _get_hue_levels()
static var sv_levels: Array = hue_levels.slice(0, int(hue_levels.size() / 4.0))

static func _get_hue_levels():
	# Generate the hue sequence (e.g., 0, 0.5, 0.25, 0.75, 0.125, 0.325, ...)
	var _hue_levels := []
	var step: float = 1.0
	while step > 0.05: # Ensure the precision doesn't grow too high (undistinguishable colors anyway)
		for i in range(int(1 / step)):
			var hue = i * step
			if hue not in _hue_levels:
				_hue_levels.append(hue)
		step /= 2.0
	return _hue_levels

static func get_color(index: int) -> Color:
	# Compute indices for hue, brightness, and saturation
	var hue_index = index % hue_levels.size()
	var sv_index = int(index / float(hue_levels.size())) % sv_levels.size()
	 
	# Get values
	var hue = hue_levels[hue_index]
	var sv = 1.0 - hue_levels[sv_index]
	
	# Convert to RGB and return as Color
	return Color.from_hsv(hue, 0.5 + 0.5 * sv, sv)

func _run():
	# Calculate total number of possible colors
	var total_colors = hue_levels.size() * sv_levels.size()
	print("Total possible colors (before repeating): ", total_colors)
	print("Hue levels: ", hue_levels)
	
	# Generate and print the first 10 color hex codes
	for i in range(min(10, total_colors)):
		var color = get_color(i)
		print("Color ", i, ": ", color.to_html())
