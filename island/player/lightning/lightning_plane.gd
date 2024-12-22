@tool
extends MeshInstance3D

@onready var mat: ShaderMaterial = self.material_override as ShaderMaterial
@onready var unit_width: float = mat.get_shader_parameter("width") as float
@onready var noise_texture: NoiseTexture2D = mat.get_shader_parameter("noise_texture") as NoiseTexture2D
@onready var unit_freq: float = (noise_texture.noise as FastNoiseLite).frequency

@export var color: Color = Color.WHITE:
	set(new):
		color = new
		mat.set_shader_parameter("color", color)

@export var variation: float = 0.1:
	set(new):
		variation = new
		mat.set_shader_parameter("variation", variation)

@export var width: float = 0.1:
	set(new):
		width = new
		mat.set_shader_parameter("width", width)

@export var start_angle: float = 0.0:
	set(new):
		start_angle = new
		mat.set_shader_parameter("start_angle", start_angle)

@export var start_freedom: float = 0.0:
	set(new):
		start_freedom = new
		mat.set_shader_parameter("start_freedom", start_freedom)

@export var end_freedom: float = 1.0:
	set(new):
		end_freedom = new
		mat.set_shader_parameter("end_freedom", end_freedom)

func set_endpoints(a: Vector3, b: Vector3):  # Always looking up for now
	var dist := a.distance_to(b)
	scale = Vector3.ONE * dist / 2.0
	var dist_sqrt = sqrt(dist)
	width = unit_width / dist_sqrt
	(noise_texture.noise as FastNoiseLite).frequency = unit_freq * dist_sqrt
	#print("setting noise to ", unit_freq, " -- ", dist, " -- ", (noise_texture.noise as FastNoiseLite).frequency)
	global_position = (a + b) / 2.0
	# Compute rotations manually because quaternions are hard ;)
	global_rotation = Vector3.ZERO
	var dist_xz := Vector2(b.x, b.z).distance_to(Vector2(a.x, a.z))
	var angle2 := atan2(b.y - a.y, dist_xz)
	rotate_z(angle2)
	var angle1 = -atan2(b.z - a.z, b.x - a.x)
	rotate_y(angle1)
