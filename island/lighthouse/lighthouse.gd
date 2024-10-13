@tool
extends Node3D

# The color of the lighthouse's stripes and roof (to indicate the owner).
@export var color: Color:
	set(new_val):
		color = new_val
		new_mat.set_shader_parameter("color", color)
		#print("Updated lighthouse color to ", color, "!")

var new_mat := ShaderMaterial.new()
func _ready():
	var mesh_instance: MeshInstance3D = $lighthouse/Lighthouse
	new_mat.shader = preload("res://island/lighthouse/ownercolor.gdshader")
	new_mat.set_shader_parameter("tex", preload("res://island/lighthouse/model/lighthouse_lighthouse_lighthouse_color.webp"))
	mesh_instance.set_surface_override_material(0, new_mat)
	if color == null:
		color = Color.AQUA
