@tool
extends Node3D

func _on_terrain_terrain_ready(mi: MeshInstance3D) -> void:
	var start_time = Time.get_ticks_msec()
	# Create collision shape for terrain only if needed
	if not mi.get_children().any(func(c): c is PhysicsBody3D):
		mi.create_trimesh_collision()
	SLog.sd("[timing] Created collision for terrain in " + str(Time.get_ticks_msec() - start_time) + "ms")
	start_time = Time.get_ticks_msec()
	# Clear previous lighthouses
	get_children().map(func(c): c.queue_free())
	# Spawn the lighthouses at the appropriate locations...
	var lh := preload("res://island/lighthouse/lighthouse.tscn")
	var lh_wl_tex := Settings.island_water_level_distance()
	var lh_wl_image := lh_wl_tex.get_image()
	var aabb = mi.get_aabb()
	for y in range(lh_wl_image.get_height()):
		for x in range(lh_wl_image.get_width()):
			if lh_wl_image.get_pixel(x, y).g == 1.0:
				var p_rel = Vector3(float(x) / float(lh_wl_image.get_width()-1), 100.0, float(y) / float(lh_wl_image.get_height()-1))
				var p = aabb.position + aabb.size * p_rel
				var hit = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p, Vector3(p.x, -p.y, p.z)))
				if hit:
					var child = lh.instantiate()
					# TODO: child.name (with original IDs, taken from the array...!)
					child.position = hit.position
					child.color = Color(randf(), randf(), randf())
					add_child(child)
				else:
					SLog.sd("ERROR: Couldn't hit raycast to place lighthouse!!!")
	SLog.sd("[timing] Placed lighthouses in " + str(Time.get_ticks_msec() - start_time) + "ms")
