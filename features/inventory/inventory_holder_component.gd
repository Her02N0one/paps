## Component wrapper that exposes an InventoryStore on actor scene roots.
class_name InventoryHolderComponent
extends Node

@export var inventory: InventoryStore

func _ready() -> void:
	if inventory == null:
		inventory = InventoryStore.new()
		add_child(inventory)


func configure(store: InventoryStore) -> void:
	inventory = store


func add_item(definition: ItemDefinition, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	inventory.add_item(definition, quantity)
	return true


static func find_on(actor: Node) -> InventoryHolderComponent:
	var container = actor.get_node_or_null("Components")
	var children = container.get_children() if container != null else actor.get_children()
	for child in children:
		if child is InventoryHolderComponent:
			return child as InventoryHolderComponent
	return null
