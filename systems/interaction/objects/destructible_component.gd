class_name DestructibleComponent
extends Node
## Attach to a physical object. When destroy() is called, it spawns loot and frees its parent.

@export var loot_table: LootTable
@export var spawn_height_offset: float = 0.5


func destroy() -> void:
	var parent = get_parent()
	if not parent is Node3D:
		push_warning("DestructibleComponent parent must be a Node3D")
		return
		
	if loot_table:
		var raw_loot := loot_table.generate_loot()
		for payload in raw_loot:
			if payload is ItemPayload and payload.item_definition:
				# Spawn a generic PickupItem for items dropped from destruction
				# Assuming there's a default pickup item scene somewhere, or we can just 
				# rely on SpawnPayloads for destruction if items need specific meshes.
				# Actually, the prompt says "wooden_crate_break.tres" returns ItemPayloads.
				# To drop them physically, we need a default PickupItem.tscn.
				# If we don't have one, we can spawn a minimal one here.
				var pickup := _create_ephemeral_pickup(payload)
				get_tree().current_scene.add_child(pickup)
				pickup.global_position = parent.global_position + Vector3(0, spawn_height_offset, 0)
			elif payload is SpawnPayload and payload.base_scene:
				var instance = payload.base_scene.instantiate()
				if instance is Node3D:
					get_tree().current_scene.add_child(instance)
					instance.global_position = parent.global_position + Vector3(0, spawn_height_offset, 0)
					
					if payload.injected_model:
						if payload.injected_model is PackedScene:
							instance.add_child((payload.injected_model as PackedScene).instantiate())
						elif payload.injected_model is Mesh:
							var mesh_inst := MeshInstance3D.new()
							mesh_inst.mesh = payload.injected_model as Mesh
							instance.add_child(mesh_inst)
					
					if payload.injected_table and "loot_table" in instance:
						instance.set("loot_table", payload.injected_table)
						
	parent.queue_free()


func _create_ephemeral_pickup(payload: ItemPayload) -> PickupItem:
	var pickup := PickupItem.new()
	var qty := randi_range(payload.quantity_min, payload.quantity_max)
	
	if qty > 0:
		var actual_payload := payload.duplicate() as ItemPayload
		actual_payload.quantity_min = qty
		actual_payload.quantity_max = qty
		pickup._pending_loot.append(actual_payload)
		pickup._has_rolled = true
	
	# Create a basic visual (fallback, in a real game we'd want proper visuals per item)
	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.2, 0.2)
	mesh_inst.mesh = mesh
	pickup.add_child(mesh_inst)
	
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 0.2, 0.2)
	col.shape = shape
	pickup.add_child(col)
	
	var interactable := Interactable.new()
	pickup.add_child(interactable)
	pickup.interactable = interactable
	
	return pickup
