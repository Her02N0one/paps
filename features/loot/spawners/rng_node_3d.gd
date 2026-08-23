class_name RNGNode3D
extends Marker3D
## A spawner that places a single object based on a LootTable, then removes itself.

@export var loot_table: LootTable


func _ready() -> void:
	if loot_table:
		_resolve_spawns()
	queue_free()


func _resolve_spawns() -> void:
	var raw_loot := loot_table.generate_loot()
	for payload in raw_loot:
		if payload is SpawnPayload and payload.base_scene:
			var instance = payload.base_scene.instantiate()
			
			if instance is Node3D:
				get_parent().add_child.call_deferred(instance)
				instance.global_position = global_position
				instance.global_rotation = global_rotation
				
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
