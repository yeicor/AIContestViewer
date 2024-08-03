class_name GameState
extends Node

var _raw: Dictionary


func _init(_raw: Dictionary):
	self._raw = _raw


func round() -> int:
	return self._raw["round"]


func island(energy_only: bool) -> Island:
	return Island.new(self._raw["island"], energy_only)


## Island merges information about the energy contained in each walkable cell, -1 if not walkable (and detection enabled).
class Island:
	const MAX_ENERGY: int = 100  # Defined in the engine (could change in the future)
	var _grid: Array


	func _init(_raw: Dictionary, energy_only: bool):
		var energy = _raw.get("_energymap", [])
		if not energy_only:
			var walkable = _raw.get("_island", [])
			# Override non-walkable cells with -1 energy
			for y in range(len(walkable)):
				for x in range(len(walkable[y])):
					if walkable[y][x] == 0:
						energy[y][x] = -1
		self._grid = energy


	func width() -> int:
		return len(self._grid[0])


	func height() -> int:
		return len(self._grid)


	func energy_at(x: int, y: int) -> int:
		return self._grid[y][x]


	func is_walkable(x: int, y: int) -> bool:
		return self.energy_at(x, y) != -1


	func to_ascii_string() -> String:
		var s: String    = ""
		var max_digits   = max(2, ceil(log(MAX_ENERGY + 1) / log(10)))
		var y_arr: Array = range(self.height())
		# print("MAX DIGITS: " + str(max_digits))
		y_arr.reverse()  # Print top to bottom
		for y in y_arr:
			for x in range(self.width()):
				var energy = self.energy_at(x, y)
				var cell: String
				if self.is_walkable(x, y):
					cell = str(energy)
				else:
					cell = "~"  # Water
				while len(cell) < max_digits + 1:
					cell = " " + cell
				s += cell
			s += "\n"
		return s.substr(0, s.length() - 1)  # Remove last newline


func lighthouses() -> Array:
	return self._raw["lighthouses"].values().map(func(x): return Lighthouse.new(x))


class Lighthouse:
	var _raw: Dictionary


	func _init(_raw: Dictionary):
		self._raw = _raw


	func pos() -> Vector2i:
		return Vector2i(self._raw["pos"][0], self._raw["pos"][1])


	func energy() -> int:
		return self._raw["energy"]


	func owner() -> int:
		return self._raw["owner"]


	func to_ascii_string() -> String:
		return "Lighthouse at " + str(self.pos()) + " with " + str(self.energy()) + " energy, owned by " + str(self.owner())


func connections() -> Array:
	return self._raw["conns"].map(func(x): return Connection.new(x))


class Connection:
	var _raw: Array


	func _init(_raw: Array):
		self._raw = _raw


	func from() -> Vector2i:
		return Vector2i(self._raw[0][0], self._raw[0][1])


	func to() -> Vector2i:
		return Vector2i(self._raw[1][0], self._raw[1][1])


	func to_ascii_string() -> String:
		return "Connection from " + str(self.from()) + " to " + str(self.to())
