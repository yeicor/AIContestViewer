## Island merges information about the energy contained in each walkable cell, -1 if not walkable (and detection enabled).
class_name Island
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

func size() -> Vector2i:
	return Vector2i(width(), height())

func energy_at(x: int, z: int) -> int:
	return self._grid[self.height() - 1 - z][x] # Flip z axis


func is_walkable(x: int, z: int) -> bool:
	return self.energy_at(x, z) != -1


## Returns the same cells of the island, but now as a distance to the closest water-level cell (negative for water).
func distance_to_water_level() -> Array:
	var init_time: int = Time.get_ticks_msec()
	var start_time: int = init_time
	var dist: Array     = _grid.map(func(row: Array): return row.map(func(_x: int): return INF))
	# Compute the distance for all cells using dynamic programming
	# Initialize the distance to +-0.5 for boundary cells (considering outside as water)
	for z in range(self.height()):
		for x in range(self.width()):
			if dist[z][x] == INF: # Previously unvisited
				var walkable: bool       = self.is_walkable(x, z)
				var handle_dir: Callable = func(dx: int, dz: int) -> void:
					if x + dx >= 0 and x + dx < self.width() and z + dz >= 0 and z + dz < self.height():
						var dir_walkable: bool = self.is_walkable(x + dx, z + dz)
						if dir_walkable != walkable:
							dist[z][x] = 0.5 if walkable else -0.5
							if dist[z + dz][x + dx] == INF:
								dist[z + dz][x + dx] = -0.5 if walkable else 0.5
					elif walkable: # Assume edge is water
						dist[z][x] = 0.5
				handle_dir.call(-1, 0)
				handle_dir.call(1, 0)
				handle_dir.call(0, -1)
				handle_dir.call(0, 1)

	print("[timing] Distance to water level (first pass) computed in " + str(Time.get_ticks_msec() - start_time) + "ms")
	start_time = Time.get_ticks_msec()

	# Now propagate the distance to all cells
	for attempt in range(max(self.width(), self.height())):
		var changed: int = 0  # Stop attempts early when no more changes are detected
		for z in range(self.height()):
			for x in range(self.width()):
				var handle_dir: Callable = func(dx: int, dz: int) -> bool:
					if dist[z][x] != INF:
						if x + dx >= 0 and x + dx < self.width() and z + dz >= 0 and z + dz < self.height():
							var new_dist: float = dist[z][x] + 1.0 * sign(dist[z][x])
							if abs(new_dist) < abs(dist[z + dz][x + dx]):
								dist[z + dz][x + dx] = new_dist
								return true
					return false
				if handle_dir.call(-1, 0):
					changed += 1
				if handle_dir.call(1, 0):
					changed += 1
				if handle_dir.call(0, -1):
					changed += 1
				if handle_dir.call(0, 1):
					changed += 1
		#
		print("[timing] Distance to water level (pass " + str(attempt + 2) + ") computed in " + str(Time.get_ticks_msec() - start_time) + "ms (" + str(changed) + " changes)")
		start_time = Time.get_ticks_msec()
		if changed == 0:
			break # No more iterations needed!

	print("[timing] Distance to water level (total) computed in " + str(Time.get_ticks_msec() - init_time) + "ms")
	return dist


func to_ascii_string() -> String:
	return GameState.array_2d_to_ascii_string(_grid.map(
		func(row: Array) -> Array: return row.map(func(x: int) -> String: return str(x) if x >= 0 else "~")))
