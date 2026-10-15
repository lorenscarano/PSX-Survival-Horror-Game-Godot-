class_name AimingRay extends RayCast3D

func find_closest_target() -> AimTarget:
	var closest_distance_found := INF
	var closest_target: AimTarget = null
	
	for target in get_tree().get_nodes_in_group("aim_target"):
		look_at(target.global_position)
		force_raycast_update()
		
		if get_collider() != target:
			continue
		
		var distance_to_target = self.global_position.distance_to(target.global_position)
		
		if distance_to_target < closest_distance_found:
			closest_distance_found = distance_to_target
			closest_target = target
	
	self.rotation = Vector3.ZERO
	return closest_target
