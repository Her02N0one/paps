@tool
class_name ScatterArea3D
extends Node3D
## A spawner that randomly places objects within a defined 2D polygon mapped to the XZ plane.

@export var loot_table: LootTable
@export var scatter_polygon: PackedVector2Array = []:
	set(value):
		scatter_polygon = value
		if Engine.is_editor_hint():
			_update_debug_mesh()
@export var spawn_height_offset: float = 0.0

var _debug_mesh_instance: MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_update_debug_mesh()
		return
		
	if _debug_mesh_instance:
		_debug_mesh_instance.queue_free()
		
	if loot_table and scatter_polygon.size() >= 3:
		_resolve_spawns()


func _resolve_spawns() -> void:
	var raw_loot := loot_table.generate_loot()
	for payload in raw_loot:
		if payload is SpawnPayload and payload.base_scene:
			var instance = payload.base_scene.instantiate()
			
			if instance is Node3D:
				add_child(instance)
				
				# Place it randomly within the polygon
				var random_point := _get_random_point_in_polygon()
				# Raycast down to find the floor (assuming the scatter area is placed slightly above ground)
				var ray_start := global_position + Vector3(random_point.x, 10.0, random_point.y)
				var ray_end := ray_start + Vector3.DOWN * 50.0
				var space_state := get_world_3d().direct_space_state
				var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
				var result := space_state.intersect_ray(query)
				
				if result:
					instance.global_position = result.position + Vector3(0, spawn_height_offset, 0)
				else:
					# Fallback if no floor found
					instance.position = Vector3(random_point.x, 0, random_point.y)
				
				# Inject model if applicable
				if payload.injected_model:
					if payload.injected_model is PackedScene:
						var model_instance = (payload.injected_model as PackedScene).instantiate()
						instance.add_child(model_instance)
					elif payload.injected_model is Mesh:
						var mesh_instance := MeshInstance3D.new()
						mesh_instance.mesh = payload.injected_model as Mesh
						instance.add_child(mesh_instance)
				
				# Inject table if the instance expects one
				if payload.injected_table and "loot_table" in instance:
					instance.set("loot_table", payload.injected_table)
			else:
				instance.free()


func _get_random_point_in_polygon() -> Vector2:
	if scatter_polygon.size() < 3:
		return Vector2.ZERO
		
	# Find bounding box
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	
	for p in scatter_polygon:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)
		
	# Rejection sampling
	var max_attempts := 100
	for i in range(max_attempts):
		var test_point := Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
		if Geometry2D.is_point_in_polygon(test_point, scatter_polygon):
			return test_point
			
	return scatter_polygon[0]


func _update_debug_mesh() -> void:
	if not Engine.is_editor_hint():
		return
		
	if not _debug_mesh_instance:
		_debug_mesh_instance = MeshInstance3D.new()
		add_child(_debug_mesh_instance)
		
	if scatter_polygon.size() < 3:
		_debug_mesh_instance.mesh = null
		return
		
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	
	for p in scatter_polygon:
		vertices.append(Vector3(p.x, 0, p.y))
		
	var poly_indices := Geometry2D.triangulate_polygon(scatter_polygon)
	if poly_indices.is_empty():
		return
		
	indices.append_array(poly_indices)
	
	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_INDEX] = indices
	
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	mesh.surface_set_material(0, mat)
	_debug_mesh_instance.mesh = mesh
