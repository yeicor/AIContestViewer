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

var global_top_center: Vector3:
	get():
		var aabb := mesh_instance.get_aabb()
		return global_transform * (aabb.get_center() + Vector3(0.0, aabb.size.y / 2.0, 0.0))

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
	self.get_parent_node_3d().add_child(lp)
	lp.name = _get_conn_id(other)
	lp.start_freedom = 0.0
	lp.end_freedom = 0.0
	lp.variation = 0.02 # Almost straight line to correctly highlight triangle areas!
	var from = global_top_center
	var to = other.global_top_center
	lp.set_endpoints(from, to)

func disconnect_from(other: LighthouseScene) -> bool:
	var par := (self.parent as Node3D)
	var conn_id := self._get_conn_id(other)
	if par.has_node(conn_id):
		par.remove_child(par.get_node(conn_id))
		return true
	conn_id = other._get_conn_id(self)
	if par.has_node(conn_id):
		par.remove_child(par.get_node(conn_id))
		return true
	return false
