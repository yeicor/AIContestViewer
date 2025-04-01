#@tool
extends Node3D
class_name PlayerScene

@onready var animation_player: AnimationPlayer = $gandalf/AnimationPlayer
@onready var mesh_instance: MeshInstance3D = $gandalf/Armature/Skeleton3D/mesh_001
@onready var skeleton: Skeleton3D = $gandalf/Armature/Skeleton3D
@onready var light: SpotLight3D = $Light

var new_mat := ShaderMaterial.new()
# The color of the player
@export var color: Color:
	set(new_val):
		color = new_val
		new_mat.set_shader_parameter("color_to", color)
		if light != null: light.light_color = color

var attack_lightnings: Array = []
@onready var lightning_plane := preload("res://island/player/lightning/lightning_plane.tscn")
@onready var lightning_sphere := preload("res://island/player/lightning/lightning_sphere.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	light.light_color = color
	mesh_instance.layers = 4 # Ignored by own light
	new_mat.shader = preload("res://island/lighthouse/recolor.gdshader")
	new_mat.set_shader_parameter("tex", preload("res://island/player/model/gandalf_texture.tres"))
	new_mat.set_shader_parameter("color_from", Vector3(0.5, 0.7, 0.8))
	new_mat.set_shader_parameter("sensitivity", 0.2)
	mesh_instance.set_surface_override_material(0, new_mat)
	#
	for hand_bone_name in ["mixamorig_LeftHand", "mixamorig_RightHand"]:
		var lp := lightning_plane.instantiate()
		add_child(lp)
		lp.scale /= scale.x
		lp.name = "attack_lightning_" + hand_bone_name
		lp.color = color
		lp.start_freedom = 0.0
		lp.end_freedom = 0.3
		lp.visible = false
		var bone_id = skeleton.find_bone(hand_bone_name)
		attack_lightnings.append([lp, bone_id])
	# Make it more visible by adding ball of lightning on target
	var ls := lightning_sphere.instantiate()
	add_child(ls) 
	ls.scale /= scale.x
	ls.name = "attack_lightning_sphere"
	ls.color = color
	ls.visible = false
	attack_lightnings.append([ls])

func idle():
	if walk_from_transform != Transform3D.IDENTITY: # Force set position
		position = target
	walk_from_transform = Transform3D.IDENTITY
	anim_dest_time = anim_from_time
	target = Vector3.INF
	_anim_common("Idle", true)

func podium(order: int, _look_at: Vector3):
	if walk_from_transform != Transform3D.IDENTITY: # Force set position
		position = target
	walk_from_transform = Transform3D.IDENTITY
	anim_dest_time = anim_from_time
	target = _look_at
	_anim_common("Podium" + str(min(order + 1, 4)), true)

func walk_to(center: Vector2, _delta_secs: float = Settings.common_turn_secs()):
	# TODO: Avoid some props and follow terrain shape better? Auto-generated navmesh may cause issues?
	var walk_to_pos = Vector3(center.x, -999, center.y)
	walk_to_pos.y = max(0.0, IslandH.height_at_global(center))  # Walk on water (should not be required...)
	walk_to_3d(walk_to_pos, _delta_secs)

func set_pos(center: Vector2):
	walk_to(center, 0.0)

func attack(_target: Vector3, strength01: float = 1.0, _delta_secs: float = Settings.common_turn_secs()):
	"""Animates the attack of the center of the cell that the player is on."""
	if walk_from_transform != Transform3D.IDENTITY: # Force set position
		position = target
	walk_from_transform = Transform3D.IDENTITY
	target = _target
	for alp in attack_lightnings:
		alp[0].visible = true
		if len(alp) > 1: # Hand lightnings
			alp[0].unit_width = strength01 * 0.75
		else:
			alp[0].unit_width = strength01 * 0.5
			alp[0].scale = Vector3.ONE * 0.75 * Settings.terrain_cell_side() * strength01 / scale.x
	_anim_common("Attack", true, _delta_secs)

var walk_from_transform: Transform3D = Transform3D.IDENTITY
func walk_to_3d(destination: Vector3, _delta_secs: float = Settings.common_turn_secs()) -> void:
	"""Makes the player walk toward a specified destination."""
	if walk_from_transform != Transform3D.IDENTITY: # Force set position
		position = target
	walk_from_transform = transform
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
	var anim_progress: float
	if anim_from_time == anim_dest_time: anim_progress = 1.0
	else: anim_progress = clampf((Time.get_ticks_msec() / 1000.0 - anim_from_time) / (anim_dest_time - anim_from_time), 0.0, 1.0)

	# If walking, move towards the target based on the percentage of completion
	if walk_from_transform != Transform3D.IDENTITY:
		position = lerp(walk_from_transform.origin, target, anim_progress)
		# Actually, always stick the player to the terrain height except when 
		# the player is close and the target is not at the terrain surface (podium)
		var pos_on_terrain := Vector3(position.x, IslandH.height_at_global(Vector2(position.x, position.z)), position.z)
		var terrain_force := clampf(Vector2(target.x, target.z).distance_to(Vector2(position.x, position.z)) / Settings.terrain_cell_side() - 1.0, 0, 1)
		position = lerp(position, pos_on_terrain, terrain_force)
		ensure_no_lightnings() # If turns are too fast, end animation code may not always run

	# Always smoothly rotate to face the target
	var rotation_speed = max(PI, PI / Settings.common_turn_secs_multiplier())
	var rotation_target = -Vector3(target.x - position.x, 0.0, target.z - position.z)
	if rotation_target.length_squared() > 0.001 and rotation_target.is_finite():
		quaternion = lerp(quaternion, Basis.looking_at(rotation_target).get_rotation_quaternion(), _delta * rotation_speed)

	# If attacking, make sure the lightning is always aligned with the hands and target (even while rotating)
	for alp in attack_lightnings:
		var lightning: LightningPlane = alp[0]
		if not lightning.visible or not target.is_finite(): continue
		if len(alp) > 1: # Hand lightnings
			var lightning_from := Transform3D.IDENTITY.rotated(Vector3.RIGHT, PI/2) * \
			mesh_instance.transform * skeleton.transform * skeleton.get_bone_global_pose(alp[1]).origin
			## FIXME: target - position is "close enough" but not correct (check by reducing end_freedom)
			lightning.set_endpoints(lightning_from, (target - position) / scale.x)
		else: # Sphere lightnings at target
			lightning.global_position = target

func ensure_no_lightnings():
	for alp in attack_lightnings:
		alp[0].visible = false
