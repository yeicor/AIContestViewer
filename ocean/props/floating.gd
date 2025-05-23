#@tool
class_name Floating
extends Node3D

# Movement variables
@export var amplitude: float = 0.5
@export var frequency: float = 1.0
@export var lateral_amplitude: float = 0.2
@export var lateral_frequency: float = 0.5

# Rotation variables
@export var rotation_speed: float = 0.5
@export var rotation_amplitude: float = 0.1

var initial_transform: Transform3D
var my_offset: float

func _ready() -> void:
	initial_transform = global_transform
	my_offset = randf() * 1000.0

func _process(_delta: float) -> void:
	var time = Time.get_ticks_msec() / 1000.0 + my_offset

	# Movement offsets
	var vertical_offset = sin(time * frequency) * amplitude
	var lateral_offset_x = sin(time * lateral_frequency) * lateral_amplitude
	var lateral_offset_z = cos(time * lateral_frequency) * lateral_amplitude
	global_transform.origin = initial_transform.origin + Vector3(lateral_offset_x, vertical_offset, lateral_offset_z)

	# Rotation tilts
	var tilt_x = sin(time * rotation_speed) * rotation_amplitude
	var tilt_z = cos(time * rotation_speed) * rotation_amplitude
	global_transform.basis = initial_transform.basis * Basis(Vector3(1, 0, 0), tilt_x).rotated(Vector3(0, 0, 1), tilt_z)
