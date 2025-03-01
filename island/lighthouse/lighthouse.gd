@tool
extends Node3D
class_name LighthouseScene

var meta: Lighthouse

@onready var mesh_instance: MeshInstance3D = $lighthouse/Lighthouse

var new_mat := ShaderMaterial.new()
# The color of the lighthouse's stripes and roof (to indicate the owner).
@export var color: Color:
	set(new_val):
		color = new_val
		new_mat.set_shader_parameter("color_to", color)
		#print("Updated lighthouse color to ", color, "!")

var top_center: Vector3:
	get():
		var aabb := mesh_instance.get_aabb()
		return (aabb.get_center() + Vector3(0.0, aabb.size.y / 2.0, 0.0))

static func from_meta(_meta: Lighthouse, global_pos: Vector3) -> LighthouseScene:
	var slf: LighthouseScene = load("res://island/lighthouse/lighthouse.tscn").instantiate()
	slf.meta = _meta
	slf.name = "Lighthouse@" + str(_meta.pos())
	slf.position = global_pos
	slf.rotate_y(randf() * 2 * PI)
	slf.color = Color(0.3, 0.3, 0.3)  # Non-player color when unowned
	slf.color = ColorGenerator.get_color(_meta.pos().x)  # Only for testing visibility
	return slf

func _ready():
	new_mat.shader = preload("res://island/lighthouse/recolor.gdshader")
	new_mat.set_shader_parameter("tex", preload("res://island/lighthouse/model/lighthouse_lighthouse_lighthouse_color.webp"))
	new_mat.set_shader_parameter("color_from", Vector3(0.7, 0.0, 0.0))
	mesh_instance.set_surface_override_material(0, new_mat)
	if color == null:
		color = Color.AQUA

func _get_conn_id(other: LighthouseScene) -> String:
	return "LHConnection@"+str(meta.pos())+","+str(other.meta.pos())

func connect_to(other: LighthouseScene):
	var lp := preload("res://island/player/lightning/lightning_plane.tscn").instantiate()
	self.add_child(lp)
	lp.name = _get_conn_id(other)
	lp.start_freedom = 0.0
	lp.end_freedom = 0.0
	lp.variation = 0.025 # Almost straight line to correctly highlight triangle areas!
	lp.set_endpoints(top_center, transform.inverse() * other.transform * top_center)

func disconnect_from(other: LighthouseScene) -> bool:
	var conn_id := self._get_conn_id(other)
	if has_node(conn_id):
		remove_child(get_node(conn_id))
		return true
	conn_id = other._get_conn_id(self)
	if has_node(conn_id):
		remove_child(get_node(conn_id))
		return true
	return false
