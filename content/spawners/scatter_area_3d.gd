@tool
class_name ScatterArea3D
extends Node3D
## A spawner that randomly places objects within a defined 2D polygon mapped to the XZ plane.
# TODO: Maybe this should use a area3D instead, and use very light calculations to drop to the lowest collision point it can. pros: a lot easier to make in the editor. cons: might be harder to get exact shapes, adds an extra third dimension to consider (this could also be a pro, i.e. filling shelves).
@export var persistent_id: String = ""
@export var loot_table: LootTable
@export var scatter_polygon: PackedVector2Array = []:
	set(value):
		scatter_polygon = value
		if Engine.is_editor_hint():
			_update_debug_mesh()
@export var spawn_height_offset: float = 0.0
@export var bake_scatter: bool = false:
	set(value):
		if Engine.is_editor_hint() and value:
			_bake_scatter()

var _debug_mesh_instance: MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_update_debug_mesh()
		return
		
	if _debug_mesh_instance:
		_debug_mesh_instance.queue_free()
		
	_check_and_resolve_spawns()

func _check_and_resolve_spawns() -> void:
	if not loot_table or scatter_polygon.size() < 3:
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
	# Use local position instead of global to guarantee absolute stability across scene loads,
	# rounding to avoid any floating-point serialization inaccuracies.
	var stable_seed = base_id if not persistent_id.is_empty() else (base_id + str(int(position.x * 100)) + str(int(position.z * 100)))
	rng.seed = hash(stable_seed)
	
	var raw_loot := loot_table.generate_loot(rng)
	var spawn_index := 0
	
	for payload in raw_loot:
		if payload is SpawnPayload and payload.base_scene:
			var instance = payload.base_scene.instantiate()
			
			if instance is Node3D:
				# Generate deterministic ID for the dynamic item
				if "persistent_id" in instance:
					instance.set("persistent_id", base_id + "_dyn_" + str(spawn_index))
					spawn_index += 1
				
				# Inject table if the instance expects one
				if payload.injected_table and "loot_table" in instance:
					instance.set("loot_table", payload.injected_table)
					
				add_child(instance)
				
				# Place it randomly within the polygon using the RNG synchronously to preserve deterministic RNG state
				var random_point := _get_random_point_in_polygon(rng)
				
				# Defer the raycast to allow physics server to update collision shapes on level load
				_apply_placement_deferred(instance, random_point, spawn_height_offset)
				
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

func _apply_placement_deferred(instance: Node3D, random_point: Vector2, height_offset: float) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	if not is_instance_valid(instance) or not instance.is_inside_tree():
		return
		
	var ray_start := global_position + Vector3(random_point.x, 10.0, random_point.y)
	var ray_end := ray_start + Vector3.DOWN * 50.0
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	var result := space_state.intersect_ray(query)
	
	if result:
		instance.global_position = result.position + Vector3(0, height_offset, 0)
	else:
		instance.position = Vector3(random_point.x, 0, random_point.y)

func _bake_scatter() -> void:
	if not Engine.is_editor_hint() or not loot_table or scatter_polygon.size() < 3:
		return
		
	var raw_loot := loot_table.generate_loot()
	var spawn_index := 0
	
	for payload in raw_loot:
		if payload is SpawnPayload and payload.base_scene:
			var instance = payload.base_scene.instantiate()
			
			if instance is Node3D:
				# Generate deterministic ID for the baked item
				if "persistent_id" in instance:
					var base_id = persistent_id if not persistent_id.is_empty() else name
					instance.set("persistent_id", base_id + "_baked_" + str(spawn_index))
					spawn_index += 1
				
				# Inject table if the instance expects one
				if payload.injected_table and "loot_table" in instance:
					instance.set("loot_table", payload.injected_table)
					
				add_child(instance)
				instance.owner = get_tree().edited_scene_root
				
				var random_point := _get_random_point_in_polygon(null)
				# In editor, raycasts don't always work reliably without a running physics server. 
				# We will just place it at the offset relative to our height.
				instance.position = Vector3(random_point.x, spawn_height_offset, random_point.y)
				
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
		var test_point := Vector2(rng.randf_range(min_x, max_x) if rng else randf_range(min_x, max_x), rng.randf_range(min_y, max_y) if rng else randf_range(min_y, max_y))
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
