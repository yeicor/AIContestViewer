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


## Returns an array of size 2 * cell_counts + 1, but each value of the array is the distance
## to the closest water-level point, in cells (negative for water).
func distance_cell_corners_to_water_level() -> Array:
	var init_time: int = Time.get_ticks_msec()
	var start_time: int = init_time
	var array_size := 2 * size() + Vector2i(1, 1)  # One value for each corner and each midpoint!
	var map_array_to_cell = func(a: Vector2i):
		return a / Vector2i(2, 2) # Last column/row cells have an out-of-bounds point...
	var is_corner_or_edge = func(a: Vector2i):
		return a.x % 2 == 0 or a.y % 2 == 0

	# Create the solution array as INF, of size (width + 1) x (height + 1) to include the corners
	var dist := []
	for z in range(array_size.y):
		var xs := []
		for x in range(array_size.x):
			xs.push_back(INF)
		dist.push_back(xs)

	# Compute the distance for all cells using dynamic programming
	# Step 1: Find edges of the island and set their distance to 0
	for ay in range(array_size.y):
		for ax in range(array_size.x):
			var axy := Vector2i(ax, ay)
			var xy: Vector2i = map_array_to_cell.call(axy)
			if (xy.x == 0 and xy.y < self.height() or xy.y == 0 and xy.x < self.height()) and self.is_walkable(xy.x, xy.y):
				assert(false, "Unconsidered case of land on edges of map... (please add water row or column)")
			if (xy.x == self.width() and xy.y > 0 or xy.y == self.height() and xy.x > 0) and self.is_walkable(xy.x - 1, xy.y - 1):
				assert(false, "Unconsidered case of land on edges of map... (please add water row or column)")
			var x1y1 = map_array_to_cell.call(axy - Vector2i(1, 1))
			if xy.x > 0 and xy.y > 0 and xy.x < self.width() and xy.y < self.height() and \
				is_corner_or_edge.call(axy) and (
				self.is_walkable(x1y1.x, x1y1.y) != self.is_walkable(xy.x, x1y1.y) or
				self.is_walkable(x1y1.x, x1y1.y) != self.is_walkable(x1y1.x, xy.y) or
				self.is_walkable(xy.x, x1y1.y) != self.is_walkable(xy.x, xy.y) or
				self.is_walkable(x1y1.x, xy.y) != self.is_walkable(xy.x, xy.y)):
				dist[ay][ax] = 0.0

	SLog.sd("[timing] Distance to water level (first pass) computed in " + str(Time.get_ticks_msec() - start_time) + "ms")
	start_time = Time.get_ticks_msec()

	# Now propagate the distance to all cells
	for attempt in range(max(array_size.x, array_size.y)):
		var changed: int = 0  # Stop attempts early when no more changes are detected
		for ay in range(array_size.y):
			for ax in range(array_size.x):
				var axy := Vector2i(ax, ay)
				var handle_dir: Callable = func(dx: int, dy: int) -> bool:
					if dist[ay][ax] != INF:
						if ax + dx >= 0 and ax + dx < array_size.x and ay + dy >= 0 and ay + dy < array_size.y:
							var xy_other = map_array_to_cell.call(Vector2i(ax + dx, ay + dy))
							var is_above = xy_other.x < self.width() and xy_other.y < self.height() and self.is_walkable(xy_other.x, xy_other.y)
							var new_dist: float = dist[ay][ax] + (0.5 if is_above else -0.5) # Higher LOD: half cell steps!
							if abs(new_dist) < abs(dist[ay + dy][ax + dx]):
								dist[ay + dy][ax + dx] = new_dist
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
		
		SLog.sd("[timing] Distance to water level (pass " + str(attempt + 2) + ") computed in " + str(Time.get_ticks_msec() - start_time) + "ms (" + str(changed) + " changes)")
		start_time = Time.get_ticks_msec()
		if changed == 0:
			break # No more iterations needed!

	SLog.sd("[timing] Distance to water level (total) computed in " + str(Time.get_ticks_msec() - init_time) + "ms")
	return dist


func to_ascii_string() -> String:
	return GameState.array_2d_to_ascii_string(_grid.map(
		func(row: Array) -> Array: return row.map(func(x: int) -> String: return str(x) if x >= 0 else "~")))
