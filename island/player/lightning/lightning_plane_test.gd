@tool
extends Node3D

@onready var start = $Start
@onready var start_last_loc: Vector3 = Vector3.INF
@onready var end = $End
@onready var end_last_loc: Vector3 = Vector3.INF

@onready var lightning = $LightningPlane

func _ready():
	lightning.end_freedom = 0.0

func _process(delta: float) -> void:
	if start.global_position != start_last_loc or end.global_position != end_last_loc:
		lightning.set_endpoints(start.global_position, end.global_position)
		start_last_loc = start.global_position
		end_last_loc = end.global_position
	
