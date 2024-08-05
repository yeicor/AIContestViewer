class_name Lighthouse

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

