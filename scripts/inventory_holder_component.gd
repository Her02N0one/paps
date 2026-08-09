class_name InventoryHolderComponent
extends Node

@export var inventory: InventoryStore


func configure(store: InventoryStore) -> void:
	inventory = store


func add_item(data: ItemData, quantity: int = 1) -> bool:
	if inventory == null or data == null or quantity <= 0:
		return false
	inventory.add_item(data, quantity)
	return true


static func find_on(actor: Node) -> InventoryHolderComponent:
	if actor == null:
		return null
	for child in actor.get_children():
		if child is InventoryHolderComponent:
			return child as InventoryHolderComponent
	return null