@tool
extends EditorScript
class_name DiamondSquare

# Function to ensure that the input map is a square with a power of 2 size (+1),
# padding if necessary and allowing fractional scaling for more details.
# TODO: Returns [new_input_map, actual_scale], as the scale is modified for minimal padding.
static func _prepare_input_map(input_map: Array, scale: float = 1) -> Array:
	var sizeX: int = input_map.size()
	var sizeY: int = input_map.map(func(x): return x.size()).max()
	var size: int  = 1
	while size < sizeX or size < sizeY:
		size *= 2
	size += 1
	var heightmap: Array = []
	var to_pad: Vector2  = Vector2(size - sizeX, size - sizeY)
	print("Padding input map to size: " + str(size) + " with " + str(to_pad) + " padding")
	for x in range(size):
		heightmap.append([])
		for y in range(size):
			var should_pad: bool = x < to_pad.x/2 or x >= sizeX + to_pad.x/2 or y < to_pad.y/2 or y >= sizeY + to_pad.y/2
			if should_pad:
				heightmap[x].append(-1)  # Water around the centered island
			else:
				heightmap[x].append(input_map[x - to_pad.x/2][y - to_pad.y/2])
	return heightmap


# Diamond-Square algorithm
static func _diamond_square(heightmap: Array, size: int, steepness: float, rng: RandomNumberGenerator):
	# Set the corners to their expected values
	_set_height(heightmap, 0, 0, 0, steepness, rng)
	_set_height(heightmap, size - 1, 0, 0, steepness, rng)
	_set_height(heightmap, 0, size - 1, 0, steepness, rng)
	_set_height(heightmap, size - 1, size - 1, 0, steepness, rng)

	# Iterate over the steps while decreasing the scale
	var step_size: int = size - 1
	while step_size > 1:
		var half_step: int = step_size / 2
		print("Diamond-square step with size: " + str(step_size) + " and scale: " + str(steepness))

		for x in range(0, size - 1, step_size):
			for y in range(0, size - 1, step_size):
				_diamond_step(heightmap, x, y, step_size, steepness, rng)

		for x in range(0, size, half_step):
			for y in range((x + half_step) % step_size, size, step_size):
				_square_step(heightmap, x, y, step_size, steepness, rng)

		step_size /= 2
		steepness /= 2.0


# Diamond step
static func _diamond_step(heightmap: Array, x: int, y: int, size: int, scale: float, rng: RandomNumberGenerator):
	var half_size: int = size / 2
	var avg: float     = (heightmap[x][y] + heightmap[x + size][y] + heightmap[x][y + size] + heightmap[x + size][y + size]) / 4.0
	_set_height(heightmap, x + half_size, y + half_size, avg, scale, rng)


# Square step
static func _square_step(heightmap: Array, x: int, y: int, size: int, scale: float, rng: RandomNumberGenerator):
	var half_size: int = size / 2
	var avg: float     = 0.0
	var count: int     = 0
	if x >= 0:
		avg += heightmap[x][y - half_size]
		count += 1
	if x + size <= heightmap.size() - 1:
		avg += heightmap[x + size][y - half_size]
		count += 1
	if y >= 0:
		avg += heightmap[x - half_size][y]
		count += 1
	if y + size <= heightmap.size() - 1:
		avg += heightmap[x - half_size][y + size]
		count += 1
	avg /= count
	_set_height(heightmap, x, y, avg, scale, rng)


# Set height function (shared by diamond and square steps). Enforces original heightmap above/below water level
static func _set_height(heightmap: Array, x: int, y: int, average: float, scale: float, rng: RandomNumberGenerator):
	var wants_water: bool = heightmap[x][y] == -1
	if not wants_water:
		var first: bool       = true
		while first or heightmap[x][y] < 0:
			first = false
			heightmap[x][y] = rng.randfn(average, scale)
			scale *= 1.1 # Try with a wider deviation if the first attempt was not enough
	else: # Force always deeper for nicer visuals
		var closest_surface_distance: float = heightmap.size() * 2
		for xx in range(heightmap.size()):
			for yy in range(heightmap[xx].size()):
				if heightmap[xx][yy] >= 0:
					var distance: float = Vector2(xx - x, yy - y).length()
					if distance < closest_surface_distance:
						closest_surface_distance = distance
		heightmap[x][y] = -closest_surface_distance - 0.1



# print("Set height at: " + str(x) + ", " + str(y) + " to: " + str(heightmap[x][y]) + " wants water: " + str(wants_water)+ " average: " + str(average))


# Generate heightmap
static func generate_heightmap(input_map: Array, _seed: int) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.set_seed(_seed)
	var heightmap: Array = _prepare_input_map(input_map)
	_diamond_square(heightmap, heightmap.size(), 1, rng)
	return heightmap


# Example usage
func _run():
	var input_map: Array = [
							   [-1, -1, -1, -1, -1],
							   [-1, 0, 0, 0, -1],
							   [-1, 0, 0, 0, -1],
							   [-1, 0, 0, -1, -1],
							   [-1, -1, -1, -1, -1]
						   ]
	var heightmap: Array = generate_heightmap(input_map, 42)
	print(heightmap)
