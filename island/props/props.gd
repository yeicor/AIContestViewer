@tool
extends Node3D

var start_time := 0

func _on_terrain_terrain_ready(mi: MeshInstance3D) -> void:
	#Common
	start_time = Time.get_ticks_msec()
	var seed := Settings.common_seed()
	var aabb = mi.get_aabb()
	var above_water_pos := Vector3(0, aabb.end.y / 2, 0)
	var above_water_scale: Vector3 = aabb.size + Vector3(0, aabb.position.y, 0)
	var num_cells := Settings.island_water_level_distance().get_size()
	var props_mult := Settings.common_props_multiplier()
	if props_mult < 1.0:
		props_mult = pow(props_mult, 4.0)  # More intense reduction
	
	#TreesAndRocks
	$TreesAndRocks.global_seed = seed
	$TreesAndRocks/ScatterShape.position = above_water_pos
	$TreesAndRocks/ScatterShape.scale = above_water_scale
	$TreesAndRocks.modifier_stack.stack[0].amount = int(2.0 * num_cells.x * num_cells.y * props_mult)
	SLog.sd("Building " + str($TreesAndRocks.modifier_stack.stack[0].amount) + " TreesAndRocks...")
	$TreesAndRocks.chunk_dimensions = Vector3.ONE * 20.0 * aabb.size / Vector3(num_cells.x, 1, num_cells.y)
	$TreesAndRocks.enabled = true
	
	# GrassAndBushes
	$GrassAndBushes.global_seed = seed
	$GrassAndBushes/ScatterShape.position = above_water_pos
	$GrassAndBushes/ScatterShape.scale = above_water_scale
	$GrassAndBushes.modifier_stack.stack[0].spacing = Vector3.ONE * 2.0 / props_mult
	var same_grid_GrassAndBushes := 1
	for i in range(1, same_grid_GrassAndBushes):
		$GrassAndBushes.modifier_stack.stack[i].spacing = $GrassAndBushes.modifier_stack.stack[i - 1].spacing
	SLog.sd("Building GrassAndBushes with spacing of " + str($GrassAndBushes.modifier_stack.stack[0].spacing) + "...")
	$GrassAndBushes.modifier_stack.stack[same_grid_GrassAndBushes + 2].position = $GrassAndBushes.modifier_stack.stack[0].spacing / 2 # Uneven grid
	$GrassAndBushes.chunk_dimensions = $TreesAndRocks.chunk_dimensions
	$GrassAndBushes.enabled = true


func _on_TreesAndRocks_build_completed() -> void:
	SLog.sd("[timing] TreesAndRocks build completed after " + str(Time.get_ticks_msec() - start_time) + " ms")


func _on_GrassAndBushes_build_completed() -> void:
	SLog.sd("[timing] GrassAndBushes build completed after " + str(Time.get_ticks_msec() - start_time) + " ms")
