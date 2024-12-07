@tool
extends Node3D

var new_mat := ShaderMaterial.new()
# The color of the lighthouse's stripes and roof (to indicate the owner).
@export var color: Color:
	set(new_val):
		color = new_val
		new_mat.set_shader_parameter("color_to", color)
		#print("Updated lighthouse color to ", color, "!")

func _ready():
	var mesh_instance: MeshInstance3D = $lighthouse/Lighthouse
	new_mat.shader = preload("res://island/lighthouse/recolor.gdshader")
	new_mat.set_shader_parameter("tex", preload("res://island/lighthouse/model/lighthouse_lighthouse_lighthouse_color.webp"))
	new_mat.set_shader_parameter("color_from", Vector3(0.7, 0.0, 0.0))
	mesh_instance.set_surface_override_material(0, new_mat)
	if color == null:
		color = Color.AQUA
