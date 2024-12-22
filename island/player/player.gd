@tool
extends Node3D

@export var terrain_mi: MeshInstance3D
@onready var animation_player: AnimationPlayer = $gandalf/AnimationPlayer
@onready var skeleton: Skeleton3D = $gandalf/Armature/Skeleton3D

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
	_idle()

func _idle():
	_anim_common("Idle", true)
	anim_dest_time = -1

func walk_to(global_center: Vector2, _delta_secs: float = Settings.common_turn_secs()):
	# TODO: Avoid some props and follow terrain shape better? Auto-generated navmesh may cause issues?
	var walk_to_pos = Vector3(global_center.x, -999, global_center.y)
	if terrain_mi:
		var hit = IslandH.height_at_global(global_center)
		if hit:
			walk_to_pos = hit.position
		else:
			SLog.sw("Walk to raycast failed!")
	else:
		SLog.sw("Walk terrain not set!")
	walk_to_pos.y = max(0.0, walk_to_pos.y)  # Walk on water
	_walk_to(walk_to_pos, _delta_secs)

var attack_lightnings: Array = []
func attack(_target: Vector3, _delta_secs: float = Settings.common_turn_secs()):
	"""Animates the attack of the center of the cell that the player is on."""
	for hand_bone_name in ["mixamorig_LeftHand", "mixamorig_RightHand"]:
		var lp := preload("res://island/player/lightning/lightning_plane.tscn").instantiate()
		add_child(lp)
		lp.name = "attack_lightning_" + hand_bone_name
		lp.start_freedom = 0.0
		lp.end_freedom = 0.0 # TODO: 1.0
		lp.color = color
		var bone_id = skeleton.find_bone(hand_bone_name)
		attack_lightnings.append([bone_id, lp])
	target = _target
	_anim_common("Attack", false, _delta_secs)

var walk_from_transform: Transform3D = Transform3D.IDENTITY
func _walk_to(destination: Vector3, _delta_secs: float = Settings.common_turn_secs()) -> void:
	"""Makes the player walk toward a specified destination."""
	walk_from_transform = global_transform.orthonormalized()
	target = destination
	_anim_common("Run", true, _delta_secs)

func _anim_common(_name: String, loop: bool, _delta_secs: float = Settings.common_turn_secs()):
	anim_from_time = Time.get_ticks_msec() / 1000.0
	anim_dest_time = anim_from_time + _delta_secs
	animation_player.play(_name, _delta_secs / 4.0)  # Switch smoothly
	if loop:
		animation_player.animation_set_next(_name, _name)
	else:
		animation_player.speed_scale = _delta_secs / animation_player.current_animation_length

var target: Vector3 = Vector3.INF
var anim_from_time: float = 0
var anim_dest_time: float = -1
func _process(_delta: float) -> void:
	# Determine the percentage of walk completion (0 to 1+)
	var anim_progress = (Time.get_ticks_msec() / 1000.0 - anim_from_time) / (anim_dest_time - anim_from_time)
	
	if anim_progress >= 0.0 and anim_progress < 1.0:
		# If walking, move towards the target based on the percentage of completion
		if walk_from_transform != Transform3D.IDENTITY:
			global_position = lerp(walk_from_transform.origin, target, anim_progress)
			# Actually, always stick the player to the terrain height (performance?)
			global_position.y = IslandH.height_at_global(Vector2(global_position.x, global_position.z))

		# Always smoothly rotate to face the target while walking towards it
		var rotation_speed = PI / Settings.common_turn_secs_multiplier()
		var rotation_target = -Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
		if(rotation_target.length_squared() > 0.001):
			quaternion = lerp(quaternion, Basis.looking_at(rotation_target).get_rotation_quaternion(), _delta * rotation_speed)
		
		# If attacking, make sure the lightning is always aligned with the hands and target (even while rotating)
		if not attack_lightnings.is_empty():
			for alp in attack_lightnings:
				var bone_pos := skeleton.global_transform # * skeleton.get_bone_global_pose(alp[0])
				var lp = alp[1]
				lp.set_endpoints(bone_pos.origin, target)
		
	else: # Not animating
		if walk_from_transform != Transform3D.IDENTITY:
			if global_position != target: # End of walking event
				walk_from_transform = Transform3D.IDENTITY
				global_position = target
				_idle()
		
		if not attack_lightnings.is_empty(): # End of attacking event
			for alp in attack_lightnings:
				var lp = alp[1]
				remove_child(lp)
			attack_lightnings = []
			_idle()
		
