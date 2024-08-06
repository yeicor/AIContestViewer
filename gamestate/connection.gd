class_name Connection

var _raw: Array


func _init(raw: Array):
	self._raw = raw


func from() -> Vector2i:
	return Vector2i(self._raw[0][0], self._raw[0][1])


func to() -> Vector2i:
	return Vector2i(self._raw[1][0], self._raw[1][1])


func to_ascii_string() -> String:
	return "Connection from " + str(self.from()) + " to " + str(self.to())
