class_name Player


var _raw: Dictionary


func _init(raw: Dictionary):
	self._raw = raw


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
