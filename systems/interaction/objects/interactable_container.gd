class_name InteractableContainer
extends Node3D
## Represents a searchable 3D object that populates its own inventory from a LootTable.

@export var loot_table: LootTable
@onready var interactable: Interactable = $Interactable
@onready var inventory_holder: InventoryHolderComponent = $InventoryHolderComponent

var _has_rolled: bool = false


func _ready() -> void:
	if interactable:
		interactable.interact.connect(_on_interact)
	
	# Delay the roll until first interaction or just do it on ready.
	# Doing it on ready allows the container to be pre-populated.
	if loot_table and not _has_rolled and inventory_holder and inventory_holder.inventory:
		_roll_loot()


func _roll_loot() -> void:
	_has_rolled = true
	var raw_loot := loot_table.generate_loot()
	
	for payload in raw_loot:
		if payload is ItemPayload and payload.item_definition:
			var qty := randi_range(payload.quantity_min, payload.quantity_max)
			if qty > 0:
				inventory_holder.add_item(payload.item_definition, qty)


func _on_interact(actor: Node3D) -> void:
	# Trigger the UI to open the container's inventory.
	# Depending on how the game's UI system is set up, this might emit a signal or call a UI manager.
	# Based on interactable.gd we can request interaction:
	interactable.request_player_interaction(&"open_container", actor, {"container": self})
