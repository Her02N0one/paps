@tool
## World search object: handles interaction label, persistence checks, and collection emit.
## Evaluates a LootTable to determine its contents.
class_name SearchObject
extends StaticBody3D

signal collected(persistent_id: String, dynamic_id: String)

@export_group("Configuration")
@export var loot_table: LootTable
@export var object_name: String = ""
@export var lifespan: float = 0.0

@export_group("Persistence")
@export var is_persistent: bool = true

@export_group("Dependencies")
@export var inventory_holder: InventoryHolderComponent
@export var interaction: Interactable

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not interaction:
		warnings.append("Missing Interactable node. The player will not be able to interact with this object.")
	if not inventory_holder:
		warnings.append("Missing InventoryHolderComponent node. The object cannot store generated loot.")
	return warnings

var _has_rolled: bool = false
var dynamic_id := ""
var _auto_id := ""

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if lifespan > 0.0:
		get_tree().create_timer(lifespan).timeout.connect(queue_free)
		
	var final_name := object_name
	if final_name.is_empty():
		var regex := RegEx.new()
		regex.compile("\\d+$")
		final_name = regex.sub(String(name), "").capitalize()
		
	interaction.interact.connect(_on_interacted)
	interaction.set("interact_label", "Search " + final_name)
		
	if is_persistent and dynamic_id.is_empty():
		_auto_id = String(name)
		var gs := ServiceRegistry.game_state
		var pickup_manager = ServiceRegistry.pickup_manager
		if pickup_manager:
			if pickup_manager.is_static_pickup_collected(gs.current_area, _auto_id):
				queue_free()


func _on_interacted(actor: Node3D) -> void:
	var actor_inventory := InventoryHolderComponent.find_on(actor)
	
	if not _has_rolled:
		_has_rolled = true
		if loot_table:
			var raw_loot := loot_table.generate_loot()
			for payload in raw_loot:
				if payload is ItemPayload and payload.item_definition:
					var qty := randi_range(payload.quantity_min, payload.quantity_max)
					if qty > 0:
						inventory_holder.add_item(payload.item_definition, qty)
		
	var slots := inventory_holder.inventory.get_slots()
	if slots.is_empty():
		collected.emit(_auto_id, dynamic_id)
		queue_free()
		return
		
	var remaining := false
	for slot in slots:
		var instance = slot.instance
		if actor_inventory.add_item(instance.definition, instance.quantity):
			inventory_holder.inventory.remove_item(instance.definition, instance.quantity)
		else:
			remaining = true
			
	if not remaining or inventory_holder.inventory.get_slots().is_empty():
		collected.emit(_auto_id, dynamic_id)
		queue_free()
