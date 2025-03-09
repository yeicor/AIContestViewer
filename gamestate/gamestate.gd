class_name GameState

var _raw: Dictionary


func _init(raw: Dictionary):
	self._raw = raw


func round() -> int:
	return self._raw["round"]

var _island := {}
func island(energy_only: bool = true) -> Island:
	if not _island.has(energy_only):
		_island[energy_only] = Island.new(self._raw["island"], energy_only)
	return _island[energy_only]


var _players = null
func players() -> Array:
	if _players == null: _players = self._raw["players"].map(func(x): return Player.new(x))
	return _players


var _lighthouses = null
func lighthouses() -> Array:
	if _lighthouses == null: _lighthouses = self._raw["lighthouses"].values().map(func(x): return Lighthouse.new(x))
	return _lighthouses


var _connections = null
func connections() -> Array:
	if _connections == null: _connections = self._raw["conns"].map(func(x): return Connection.new(x))
	return _connections


static func array_2d_to_ascii_string(arr: Array, blank: int = 1) -> String:
	var s: String               = ""
	var column_cell_size: Array = []
	for coli in range(len(arr[0])): # Assume same length rows.
		column_cell_size.append(arr.map(func(row: Array) -> int: return row[coli].length()).max() + blank)
	#Log.d("column_cell_size: " + str(column_cell_size))
	for z in range(len(arr)):
		for x in range(len(arr[z])):
			var cell = arr[z][x]
			while len(cell) < column_cell_size[x]:
				cell = " " + cell
			s += cell
		s += "\n"
	return s.substr(0, s.length() - 1)  # Remove last newline
