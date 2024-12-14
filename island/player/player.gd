@tool
extends Node3D

@export var terrain_mi: MeshInstance3D
@onready var animation_player = $gandalf/AnimationPlayer

var new_mat := ShaderMaterial.new()
# The color of the player
@export var color: Color:
	set(new_val):
		color = new_val
		new_mat.set_shader_parameter("color_to", color)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var mesh_instance: MeshInstance3D = $gandalf/Armature/Skeleton3D/mesh_001
	new_mat.shader = preload("res://island/lighthouse/recolor.gdshader")
	new_mat.set_shader_parameter("tex", preload("res://island/player/model/gandalf_texture.tres"))
	new_mat.set_shader_parameter("color_from", Vector3(0.5, 0.7, 0.8))
	new_mat.set_shader_parameter("sensitivity", 0.2)
	mesh_instance.set_surface_override_material(0, new_mat)
	if color == null:
		color = Color.AQUA
	_idle()
	_random_walk() # Randomly walk throughout the terrain for testing

func _idle():
	walk_dest_time = -1
	animation_player.animation_set_next("Idle", "Idle")
	animation_player.play("Idle", Settings.common_turn_secs() / 4.0)

func _random_walk():
	var walk_timer = Timer.new()
	walk_timer.autostart = true
	walk_timer.wait_time = Settings.common_turn_secs()
	walk_timer.timeout.connect(func():
		var num_cells = IslandH.num_cells()
		var cur_cell = Vector2i(IslandH.global_to_cell(Vector2(global_position.x, global_position.z)))
		var next_cell = cur_cell + Vector2i(randi_range(-1, 1), randi_range(-1, 1))
		next_cell.x = clamp(next_cell.x, 1, num_cells.x - 1) # Also avoids corners, but not all water cells...
		next_cell.y = clamp(next_cell.y, 1, num_cells.y - 1)
		if next_cell == cur_cell:
			_idle()
		else:
			var next_pos = IslandH.cell_to_global(Vector2(next_cell) + Vector2(0.5, 0.5))
			walk_to(next_pos, Settings.common_turn_secs()))
	add_child(walk_timer)
	walk_timer.start(0)

func walk_to(global_center: Vector2, delta_secs: float):
	var walk_to_pos = Vector3(global_center.x, -999, global_center.y)
	if terrain_mi:
		var hit = IslandH.query_terrain(terrain_mi, global_center)
		if hit:
			walk_to_pos = hit.position
		else:
			SLog.sw("Walk to raycast failed!")
	else:
		SLog.sw("Walk terrain not set!")
	walk_to_pos.y = max(0.0, walk_to_pos.y)  # Walk on water
	_walk_to(walk_to_pos, delta_secs)


var walk_from_transform: Transform3D = Transform3D()
var walk_dest_pos: Vector3 = Vector3.INF
var walk_from_time: float = 0
var walk_dest_time: float = -1
func _walk_to(destination: Vector3, delta_secs: float) -> void:
	"""Makes the player walk toward a specified destination."""
	walk_from_transform = global_transform.orthonormalized()
	walk_dest_pos = destination
	walk_from_time = Time.get_ticks_msec() / 1000.0
	walk_dest_time = walk_from_time + delta_secs
	animation_player.animation_set_next("Run", "Run")
	animation_player.play("Run", Settings.common_turn_secs() / 4.0)  # Switch to walk animation
	

func _process(_delta: float) -> void:
	# Determine the percentage of walk completion (0 to 1+)
	var walk_progress = (Time.get_ticks_msec() / 1000.0 - walk_from_time) / (walk_dest_time - walk_from_time)
	
	if walk_progress >= 0.0 and walk_progress < 1.0:
		# Move towards the target based on the percentage of completion
		global_position = lerp(walk_from_transform.origin, walk_dest_pos, walk_progress)

		# Smoothly rotate to face the target while walking towards it
		var rotation_speed = PI / Settings.common_turn_secs_multiplier()
		var rotation_target = -Vector3(walk_dest_pos.x - global_position.x, 0.0, walk_dest_pos.z - global_position.z)
		if(rotation_target.length_squared() > 0.001):
			quaternion = lerp(quaternion, Basis.looking_at(rotation_target).get_rotation_quaternion(), _delta * rotation_speed)
		
	elif global_position != walk_dest_pos and walk_dest_pos.is_finite(): # End of walking event
		global_position = walk_dest_pos
		_idle()
		
