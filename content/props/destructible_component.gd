@tool
class_name DestructibleComponent
extends Node
## Attach to a physical object. When destroy() is called, it spawns loot and frees its parent.

@export_group("Configuration")
@export var loot_table: LootTable
@export var spawn_height_offset: float = 0.5


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not get_parent() is Node3D:
		warnings.append("DestructibleComponent must be a child of a Node3D.")
	return warnings


func destroy() -> void:
	if Engine.is_editor_hint():
		return
		
	var parent = get_parent()
	if not parent is Node3D:
		push_warning("DestructibleComponent parent must be a Node3D")
		return
		
	if loot_table:
		var raw_loot := loot_table.generate_loot()
		for payload in raw_loot:
			if payload is ItemPayload and payload.item_definition:
				# Spawn a generic SearchObject for items dropped from destruction
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


func _create_ephemeral_pickup(payload: ItemPayload) -> SearchObject:
	var pickup := load("res://content/props/search_object.tscn").instantiate() as SearchObject
	var qty := randi_range(payload.quantity_min, payload.quantity_max)
	if qty > 0:
		# inventory_holder's inventory is created in _ready, so it might be null here before it enters the tree.
		# But since we just instanciated it, wait, _ready hasn't run. We need to add it to tree first?
		# Actually, we can just let _ready initialize it, but if we call add_item, we need the inventory.
		# Let's just create an InventoryStore manually if it doesn't have one.
		if not pickup.inventory_holder.inventory:
			var inv = InventoryStore.new()
			pickup.inventory_holder.inventory = inv
			pickup.inventory_holder.add_child(inv)
		pickup.inventory_holder.add_item(payload.item_definition, qty)
	return pickup
