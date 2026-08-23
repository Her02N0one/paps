## Immutable-like snapshot container for one inventory slot state.
class_name ItemStack
extends RefCounted

var id: int
var instance: ItemInstance

func _init(slot_id: int, item_instance: ItemInstance) -> void:
	id = slot_id
	instance = item_instance

func snapshot() -> ItemStack:
	return ItemStack.new(id, instance.duplicate())
