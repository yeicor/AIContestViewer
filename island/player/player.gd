@tool
extends Node3D

@export var step_size = 0.8
@onready var animation_player = $gandalf/AnimationPlayer

var new_mat := ShaderMaterial.new()
# The color of the player
@export var color: Color:
	set(new_val):
		color = new_val
		new_mat.set_shader_parameter("color_to", color)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("Idle", 1.0)
	animation_player.connect("animation_finished", func(_ignored):
		animation_player.play("Idle"))
	
	var mesh_instance: MeshInstance3D = $gandalf/Armature/Skeleton3D/mesh_001
	new_mat.shader = preload("res://island/lighthouse/recolor.gdshader")
	new_mat.set_shader_parameter("tex", preload("res://island/player/model/gandalf_texture.tres"))
	new_mat.set_shader_parameter("color_from", Vector3(0.5, 0.7, 0.8))
	new_mat.set_shader_parameter("sensitivity", 0.2)
	mesh_instance.set_surface_override_material(0, new_mat)
	if color == null:
		color = Color.AQUA
