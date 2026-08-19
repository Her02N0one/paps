## Immutable-like snapshot container for one inventory slot state.
class_name ItemStack
extends RefCounted

var id: int
var definition: ItemDefinition
var quantity: int


func _init(slot_id: int, item_definition: ItemDefinition, item_quantity: int) -> void:
	id = slot_id
	definition = item_definition
	quantity = item_quantity


func snapshot() -> ItemStack:
	# Panels receive copies to avoid mutating InventoryStore internals directly.
	return ItemStack.new(id, definition, quantity)
