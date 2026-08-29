@tool
class_name ScatterArea3D
extends Area3D
## A spawner that randomly places objects within a defined 2D polygon mapped to 3D space.
## Add a CollisionPolygon3D child to draw the area in the editor, and use its 'depth' property for the vertical bounds!

@export var persistent_id: String = ""
@export var loot_table: LootTable
@export var spawn_height_offset: float = 0.0

@export var bake_scatter: bool = false:
	set(value):
		if Engine.is_editor_hint() and value:
			_bake_scatter()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var cp := _get_collision_polygon()
	if cp == null:
		warnings.append("ScatterArea3D requires a CollisionPolygon3D child. This allows you to draw the area using the editor toolbar.")
	elif cp.polygon.size() < 3:
		warnings.append("The CollisionPolygon3D must have at least 3 points.")
	return warnings


func _get_collision_polygon() -> CollisionPolygon3D:
	for child in get_children():
		if child is CollisionPolygon3D:
			return child
	return null


func _ready() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
		return
		
	_check_and_resolve_spawns()


func _check_and_resolve_spawns() -> void:
	if not loot_table or not _get_collision_polygon():
		return
		
	# Check if we already have baked children
	var has_baked := false
	for child in get_children():
		if "persistent_id" in child:
			has_baked = true
			break
			
	if not has_baked:
		_resolve_spawns()


func _resolve_spawns() -> void:
	var rng := RandomNumberGenerator.new()
	var base_id = persistent_id if not persistent_id.is_empty() else name
	var stable_seed = base_id if not persistent_id.is_empty() else (base_id + str(int(global_position.x * 100)) + str(int(global_position.z * 100)))
	rng.seed = hash(stable_seed)
	
	var raw_loot := loot_table.generate_loot(rng)
	var spawn_index := 0
	
	for payload in raw_loot:
		if payload is SpawnPayload and payload.base_scene:
			var instance = payload.base_scene.instantiate()
			
			if instance is Node3D:
				# Generate deterministic ID for the dynamic item
				if "dynamic_id" in instance:
					instance.set("dynamic_id", base_id + "_dyn_" + str(spawn_index))
					spawn_index += 1
					
				if "object_name" in instance and not payload.display_name.is_empty():
					instance.set("object_name", payload.display_name)
				
				# Inject table if the instance expects one
				if payload.injected_table and "loot_table" in instance:
					instance.set("loot_table", payload.injected_table)
					
				add_child(instance)
				
				# Place it randomly within the polygon using the RNG synchronously to preserve deterministic RNG state
				var local_point := _get_random_point_in_polygon(rng)
				
				# Defer the raycast to allow physics server to update collision shapes on level load
				_apply_placement_deferred(instance, local_point, spawn_height_offset)
				
				# Inject model if applicable
				if payload.injected_model:
					if payload.injected_model is PackedScene:
						var model_instance = (payload.injected_model as PackedScene).instantiate()
						instance.add_child(model_instance)
					elif payload.injected_model is Mesh:
						var mesh_instance := MeshInstance3D.new()
						mesh_instance.mesh = payload.injected_model as Mesh
						instance.add_child(mesh_instance)
			else:
				instance.free()


func _apply_placement_deferred(instance: Node3D, local_point: Vector2, height_offset: float) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	if not is_instance_valid(instance) or not instance.is_inside_tree():
		return
		
	var cp := _get_collision_polygon()
	if cp == null:
		return
		
	# Determine top and bottom of the extrusion volume in global space
	var depth_half := cp.depth / 2.0
	var pt1 := cp.to_global(Vector3(local_point.x, local_point.y, -depth_half))
	var pt2 := cp.to_global(Vector3(local_point.x, local_point.y, depth_half))
	
	var ray_start := pt1 if pt1.y > pt2.y else pt2
	var ray_end := pt2 if pt1.y > pt2.y else pt1
	
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	var result := space_state.intersect_ray(query)
	
	if result:
		instance.global_position = result.position + Vector3(0, height_offset, 0)
	else:
		# Fallback to the center of the volume if raycast misses
		var center_pt := cp.to_global(Vector3(local_point.x, local_point.y, 0.0))
		instance.global_position = center_pt + Vector3(0, height_offset, 0)


func _bake_scatter() -> void:
	if not Engine.is_editor_hint() or not loot_table:
		return
	var cp := _get_collision_polygon()
	if cp == null or cp.polygon.size() < 3:
		return
		
	var raw_loot := loot_table.generate_loot()
	var spawn_index := 0
	
	for payload in raw_loot:
		if payload is SpawnPayload and payload.base_scene:
			var instance = payload.base_scene.instantiate()
			
			if instance is Node3D:
				var base_id = persistent_id if not persistent_id.is_empty() else name
				instance.name = base_id + "_baked_" + str(spawn_index)
				spawn_index += 1
				
				if "object_name" in instance and not payload.display_name.is_empty():
					instance.set("object_name", payload.display_name)
				
				if payload.injected_table and "loot_table" in instance:
					instance.set("loot_table", payload.injected_table)
					
				add_child(instance)
				instance.owner = get_tree().edited_scene_root
				
				var local_point := _get_random_point_in_polygon(null)
				
				# In editor, physics is stopped. Fallback to center of depth slice.
				# The user can just drop them to floor later using Godot's built in "Drop to floor" tool (PageDown).
				var center_pt := cp.to_global(Vector3(local_point.x, local_point.y, 0.0))
				instance.global_position = center_pt + Vector3(0, spawn_height_offset, 0)
				
				if payload.injected_model:
					if payload.injected_model is PackedScene:
						var model_instance = (payload.injected_model as PackedScene).instantiate()
						instance.add_child(model_instance)
						model_instance.owner = get_tree().edited_scene_root
					elif payload.injected_model is Mesh:
						var mesh_instance := MeshInstance3D.new()
						mesh_instance.mesh = payload.injected_model as Mesh
						instance.add_child(mesh_instance)
						mesh_instance.owner = get_tree().edited_scene_root
			else:
				instance.free()


func _get_random_point_in_polygon(rng: RandomNumberGenerator) -> Vector2:
	var cp := _get_collision_polygon()
	if cp == null or cp.polygon.size() < 3:
		return Vector2.ZERO
		
	var poly := cp.polygon
	var indices := Geometry2D.triangulate_polygon(poly)
	if indices.is_empty():
		return poly[0]
		
	# Calculate areas of all triangles to weight the random selection
	var total_area := 0.0
	var areas: PackedFloat64Array = []
	var num_triangles := indices.size() / 3
	
	for i in range(num_triangles):
		var a := poly[indices[i * 3]]
		var b := poly[indices[i * 3 + 1]]
		var c := poly[indices[i * 3 + 2]]
		var area := absf((a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y)) / 2.0)
		areas.append(area)
		total_area += area
		
	# Select a random triangle based on area weight
	var rand_area := (rng.randf() if rng else randf()) * total_area
	var selected_tri_idx := 0
	var accum := 0.0
	
	for i in range(num_triangles):
		accum += areas[i]
		if rand_area <= accum:
			selected_tri_idx = i
			break
			
	# Pick random point in selected triangle
	var A := poly[indices[selected_tri_idx * 3]]
	var B := poly[indices[selected_tri_idx * 3 + 1]]
	var C := poly[indices[selected_tri_idx * 3 + 2]]
	
	var r1 := rng.randf() if rng else randf()
	var r2 := rng.randf() if rng else randf()
	
	# Uniform distribution within a triangle
	if r1 + r2 > 1.0:
		r1 = 1.0 - r1
		r2 = 1.0 - r2
		
	return A + r1 * (B - A) + r2 * (C - A)
