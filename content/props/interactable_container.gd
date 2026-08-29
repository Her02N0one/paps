@tool
class_name InteractableContainer
extends StaticBody3D
## Represents a searchable 3D object that populates its own inventory from a LootTable.

@export_group("Configuration")
@export var loot_table: LootTable
@export var object_name: String = ""

@export_group("Persistence")
@export var is_persistent: bool = true

@export_group("Dependencies")
@export var interactable: Interactable
@export var inventory_holder: InventoryHolderComponent

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not get_node_or_null("CollisionShape3D"):
		warnings.append("Missing CollisionShape3D. The container will not intercept raycasts.")
	if not interactable:
		warnings.append("Missing Interactable node. The player will not be able to interact with this container.")
	if not inventory_holder:
		warnings.append("Missing InventoryHolderComponent node. The container cannot store its items.")
	return warnings

var _has_rolled: bool = false
var dynamic_id := ""
var _auto_id := ""

var inventory_save_data: Array:
	get:
		return inventory_holder.inventory.to_save_data()
	set(value):
		inventory_holder.inventory.load_save_data(value)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	interactable.interact.connect(_on_interact)
	
	var final_name := object_name
	if final_name.is_empty():
		var regex := RegEx.new()
		regex.compile("\\d+$")
		final_name = regex.sub(String(name), "").capitalize()
		
	interactable.set("interact_label", "Open " + final_name)
	
	if is_persistent and dynamic_id.is_empty():
		_auto_id = String(name)
		var saveable := SaveableComponent.new()
		saveable.unique_id = _auto_id
		saveable.properties_to_save = ["inventory_save_data", "_has_rolled"]
		add_child(saveable)
		
	if loot_table and not _has_rolled:
		_has_rolled = true
		var raw_loot := loot_table.generate_loot()
		for payload in raw_loot:
			if payload is ItemPayload and payload.item_definition:
				var qty := randi_range(payload.quantity_min, payload.quantity_max)
				if qty > 0:
					inventory_holder.add_item(payload.item_definition, qty)

func _on_interact(actor: Node3D) -> void:
	interactable.request_player_interaction(&"open_container", actor, {"container": self})
