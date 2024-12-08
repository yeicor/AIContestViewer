@tool
class_name TestColors
extends GridContainer

@export var regenerate: bool = false:
	set(new_val):
		get_children().map(func(c): remove_child(c))
		print("Generating colors!")
		var vps = get_viewport_rect().size
		var i := 0
		for y in range(columns * vps.y / vps.x): # Left-right and then top-bottom
			for x in range(columns):
				var p := ColorRect.new()
				p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				p.size_flags_vertical = Control.SIZE_EXPAND_FILL
				p.color = ColorGenerator.get_color(i)
				print("Setting color " + str(i) + " to " + str(p.color))
				add_child(p)
				p.owner = self # Show panels in editor and save them to the test scene
				i += 1
