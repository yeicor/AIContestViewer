extends Node3D
class_name Podium

func transform_for_player(order: int) -> Transform3D:
	"""Returns the global transform for the player that finished in the given
	position (0-indexed)"""
	if order <= 2:
		return find_child("Player"+str(order + 1)).transform
	else: # Overflow to the back.
		var my_row := 0
		var my_col := order - 3
		while my_col > _elems_per_overflow_row(my_row): # Untested code ;)
			my_col -= _elems_per_overflow_row(my_row)
			my_row += 1
		var x_off := my_col - _elems_per_overflow_row(my_row) / 2.0
		var z_off = -(my_row + 1)
		return transform.translated(Vector3(x_off * 2.1, 0, z_off * 2.1))

func _elems_per_overflow_row(row: int) -> int: return 4 + 1 * row 
