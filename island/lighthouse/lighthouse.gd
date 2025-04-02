@tool
extends Node3D
class_name LighthouseScene

static var unowned_color := Color(0.3, 0.3, 0.3)

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
	slf.name = "Lighthouse_" + str(_meta.pos())
	slf.position = global_pos
	slf.rotate_y(randf() * 2 * PI)
	slf.color = unowned_color  # Non-player color when unowned
	(func(): slf.mesh_instance.layers = 8).call_deferred()
	return slf

@onready var lightning_plane_pool := $Spawner
func _ready():
	new_mat.shader = preload("res://island/lighthouse/recolor.gdshader")
	new_mat.set_shader_parameter("tex", preload("res://island/lighthouse/model/lighthouse_lighthouse_lighthouse_color.webp"))
	new_mat.set_shader_parameter("color_from", Vector3(0.7, 0.0, 0.0))
	mesh_instance.set_surface_override_material(0, new_mat)
	if color == null:
		color = Color.AQUA
	lightning_plane_pool.despawn(await lightning_plane_pool.spawn()) # Preheat cache!

func _get_conn_id(other: LighthouseScene) -> String:
	return "LHConnection_"+str(meta.pos())+","+str(other.meta.pos())

func connect_to(other: LighthouseScene):
	var lp: LightningPlane = await lightning_plane_pool.spawn()
	lp.name = _get_conn_id(other)
	lp.layers = 2 # Ignore player lights
	lp.color = color
	lp.start_freedom = 0.0
	lp.end_freedom = 0.0
	lp.glow_strength = 1.0
	lp.set_endpoints(top_center, transform.inverse() * other.transform * top_center)
	 # Adjust width and variation depending on length!
	var wv_scale = pow(lp.scale.length_squared(), 0.25)
	lp.width = 0.15 / wv_scale
	lp.variation = 0.15 / wv_scale

func disconnect_from(other: LighthouseScene) -> bool:
	var conn := _get_connection(other)
	if conn != null:
		lightning_plane_pool.despawn(conn)
		return true
	return false

func is_connected_to(other: LighthouseScene) -> bool:
	return _get_connection(other) != null

func _get_connection(other: LighthouseScene) -> LighthouseScene:
	var conn_id := self._get_conn_id(other)
	var res := get_node_or_null(conn_id)
	if res != null:
		return res
	conn_id = other._get_conn_id(self)
	return other.get_node_or_null(conn_id)
	
