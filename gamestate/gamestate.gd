class_name GameState
extends Node

var _raw: Dictionary


func _init(raw: Dictionary):
	self._raw = raw


func round() -> int:
	return self._raw["round"]


func island(energy_only: bool = true) -> Island:
	return Island.new(self._raw["island"], energy_only)


func players() -> Array:
	return self._raw["players"].map(func(x): return Player.new(x))


func lighthouses() -> Array:
	return self._raw["lighthouses"].values().map(func(x): return Lighthouse.new(x))


func connections() -> Array:
	return self._raw["conns"].map(func(x): return Connection.new(x))



static func array_2d_to_ascii_string(arr: Array, blank: int = 1) -> String:
	var s: String               = ""
	var column_cell_size: Array = []
	for coli in range(len(arr[0])): # Assume same length rows.
		column_cell_size.append(arr.map(func(row: Array) -> int: return row[coli].length()).max() + blank)
	#print("column_cell_size: " + str(column_cell_size))
	for z in range(len(arr)):
		for x in range(len(arr[z])):
			var cell = arr[z][x]
			while len(cell) < column_cell_size[x]:
				cell = " " + cell
			s += cell
		s += "\n"
	return s.substr(0, s.length() - 1)  # Remove last newline
