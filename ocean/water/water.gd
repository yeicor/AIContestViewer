@tool
extends Node3D
class_name Ocean

signal built(size: Vector2)

@warning_ignore("unused_private_class_variable")
@export var generate_in_editor: bool = false:
	set(new_val):
		build(Vector2(210, 180))

var material: ShaderMaterial = preload("res://ocean/water/material.tres")


func _ready() -> void:
	if not Engine.is_editor_hint():
		# Automatically build the island once we know the size
		SignalBus.island_global_shader_parameters_ready.connect(func(): build(Settings.island_water_level_distance().get_size() * Settings.terrain_cell_side()), CONNECT_ONE_SHOT)


func build(size: Vector2):
	# Create or reuse the existing child node
	var oceanMeshNode: MeshInstance3D
	if not has_node("Ocean"):
		oceanMeshNode = MeshInstance3D.new()
		oceanMeshNode.name = "Ocean"
		add_child(oceanMeshNode)
	else:
		oceanMeshNode = get_node("Ocean")
	if oceanMeshNode.mesh == null:
		oceanMeshNode.mesh = PlaneMesh.new()

	# Update the plane mesh's size and material
	var pmesh        := oceanMeshNode.mesh as PlaneMesh
	var size_multiplier: float = material.get_shader_parameter("wave_fade_size_multiplier")
	pmesh.size = size * size_multiplier
	pmesh.subdivide_depth = int(sqrt(Settings.ocean_vertex_count()))
	pmesh.subdivide_width = pmesh.subdivide_depth
	material.shader.code = Settings.as_defines() + material.shader.code
	pmesh.material = material
	SLog.sd("Ocean has " + str(Vector2(pmesh.subdivide_width, pmesh.subdivide_depth)) + " cells.")
	
	# oceanMeshNode.owner = self # For debugging (remove to avoid serializing and preloading the mesh!)
	
	# Emit signal to trigger other scripts
	built.emit(pmesh.size)
