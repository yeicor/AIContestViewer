@tool
extends Node3D
class_name PlayerScene

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
	idle()

func idle():
	_anim_common("Idle", true)
	walk_from_transform = Transform3D.IDENTITY
	anim_dest_time = anim_from_time

func walk_to(global_center: Vector2, _delta_secs: float = Settings.common_turn_secs()):
	# TODO: Avoid some props and follow terrain shape better? Auto-generated navmesh may cause issues?
	var walk_to_pos = Vector3(global_center.x, -999, global_center.y)
	if terrain_mi:
		walk_to_pos.y = IslandH.height_at_global(global_center)
	else:
		SLog.sw("Walk terrain not set!")
	walk_to_pos.y = max(0.0, walk_to_pos.y)  # Walk on water
	_walk_to(walk_to_pos, _delta_secs)

func set_pos(global_center: Vector2):
	walk_to(global_center, 0.0)

var attack_lightnings: Array = []
func attack(_target: Vector3, _delta_secs: float = Settings.common_turn_secs()):
	"""Animates the attack of the center of the cell that the player is on."""
	for hand_bone_name in ["mixamorig_LeftHand", "mixamorig_RightHand"]:
		var lp := preload("res://island/player/lightning/lightning_plane.tscn").instantiate()
		get_parent().add_child(lp)
		lp.name = "attack_lightning_" + hand_bone_name
		lp.start_freedom = 0.0
		lp.end_freedom = 1.0
		# TODO: Make it more visible with more lightnings? Or strong lights or some other effect...
		lp.color = color
		var bone_id = skeleton.find_bone(hand_bone_name)
		attack_lightnings.append([bone_id, lp])
	walk_from_transform = Transform3D.IDENTITY
	target = _target
	_anim_common("Attack", true, _delta_secs)

var walk_from_transform: Transform3D = Transform3D.IDENTITY
func _walk_to(destination: Vector3, _delta_secs: float = Settings.common_turn_secs()) -> void:
	"""Makes the player walk toward a specified destination."""
	walk_from_transform = global_transform.orthonormalized()
	target = destination
	_anim_common("Run", true, _delta_secs)

var _last_anim = "None"
func _anim_common(_name: String, loop: bool, _delta_secs: float = Settings.common_turn_secs()):
	anim_from_time = Time.get_ticks_msec() / 1000.0
	anim_dest_time = anim_from_time + _delta_secs
	# Log.d("Animation SET | From: {0} | Dest: {1} | Name: {2}".format([anim_from_time, anim_dest_time, _name]))
	if loop:
		animation_player.animation_set_next(_name, _name)
	elif _delta_secs > 0.01:
		animation_player.speed_scale = _delta_secs / animation_player.current_animation_length
	if _last_anim != _name:  # To avoid resetting animation when keeping the same one
		animation_player.play(_name, _delta_secs / 4.0)  # Switch smoothly
		_last_anim = _name

var target: Vector3 = Vector3.INF
var anim_from_time: float = 0
var anim_dest_time: float = anim_from_time
func _process(_delta: float) -> void:
	# Determine the percentage of walk completion (0 to 1+)
	var anim_progress = (Time.get_ticks_msec() / 1000.0 - anim_from_time) / (anim_dest_time - anim_from_time)
	if !is_inf(anim_progress) and clampf(anim_progress, 0, 1.1) != anim_progress:
		SLog.sw("Animation progress: {0}. Time: {1} | From: {2} | Dest: {3}".format([anim_progress, Time.get_ticks_msec() / 1000.0, anim_from_time, anim_dest_time]))
	
	if anim_progress >= 0.0 and anim_progress < 1.0:
		# If walking, move towards the target based on the percentage of completion
		if walk_from_transform != Transform3D.IDENTITY:
			global_position = lerp(walk_from_transform.origin, target, anim_progress)
			# Actually, always stick the player to the terrain height (performance?)
			global_position.y = IslandH.height_at_global(Vector2(global_position.x, global_position.z))

		# Always smoothly rotate to face the target while walking towards it
		var rotation_speed = max(PI, PI / Settings.common_turn_secs_multiplier())
		var rotation_target = -Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
		if(rotation_target.length_squared() > 0.001):
			quaternion = lerp(quaternion, Basis.looking_at(rotation_target).get_rotation_quaternion(), _delta * rotation_speed)
		
		# If attacking, make sure the lightning is always aligned with the hands and target (even while rotating)
		if not attack_lightnings.is_empty():
			for alp in attack_lightnings:
				var lightning_from := skeleton.global_transform * Vector3(0.0, 0.3, -1.6) # HACK!
				var lp = alp[1]
				lp.set_endpoints(lightning_from, target)
		
	else: # Not animating
		if walk_from_transform != Transform3D.IDENTITY:
			if global_position != target: # End of walking event
				walk_from_transform = Transform3D.IDENTITY
				global_position = target
				idle()
		
		if not attack_lightnings.is_empty(): # End of attacking event
			for alp in attack_lightnings:
				var lp = alp[1]
				get_parent().remove_child(lp)
			attack_lightnings = []
			idle()
		
