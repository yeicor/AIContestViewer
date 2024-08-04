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


	func energy_at(x: int, z: int) -> int:
		return self._grid[self.height() - 1 - z][x] # Flip z axis


	func is_walkable(x: int, z: int) -> bool:
		return self.energy_at(x, z) != -1


	func to_ascii_string() -> String:
		var s: String    = ""
		var max_digits   = max(2, ceil(log(MAX_ENERGY + 1) / log(10)))
		# print("MAX DIGITS: " + str(max_digits))
		for z in range(self.height()):
			for x in range(self.width()):
				var energy: int = self.energy_at(x, z)
				var cell: String
				if self.is_walkable(x, z):
					cell = str(energy)
				else:
					cell = "~"  # Water
				while len(cell) < max_digits + 1:
					cell = " " + cell
				s += cell
			s += "\n"
		return s.substr(0, s.length() - 1)  # Remove last newline



func players() -> Array:
	return self._raw["players"].map(func(x): return Player.new(x))


class Player:
	var _raw: Dictionary


	func _init(_raw: Dictionary):
		self._raw = _raw


	func name() -> String:
		return self._raw["name"]


	func energy() -> int:
		return self._raw["energy"]


	## The ID of the player, unique for the game.
	func num() -> int:
		return self._raw["num"]


	func pos() -> Vector2i:
		return Vector2i(self._raw["pos"][0], self._raw["pos"][1])


	func score() -> int:
		return self._raw["score"]


	## Array of integers representing the lighthouse keys the player has collected.
	## TODO: Check if the order matches the lighthouse order (dictionaries may not guarantee it).
	func keys() -> Array:
		return self._raw["keys"]

	func to_ascii_string() -> String:
		return "Player " + str(self.num()) + " (" + self.name() + ") at " + str(self.pos()) + " with " + str(self.energy()) + " energy and " + str(self.score()) + " score"


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
