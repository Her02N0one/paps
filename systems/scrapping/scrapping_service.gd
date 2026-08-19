## Pure rules/service for converting inventory slots into scrap output.
class_name ScrappingService
extends RefCounted


static func can_scrap(slot: ItemStack, scrap_item: ItemDefinition) -> bool:
	# Scrap item itself is excluded to prevent self-referential conversion loops.
	return slot != null and slot.definition != scrap_item and slot.definition.scrap_yield > 0


static func get_output_quantity(slot: ItemStack, quantity: int) -> int:
	if slot == null or quantity <= 0:
		return 0
	# Clamp to slot quantity so callers can pass optimistic values safely.
	return slot.definition.scrap_yield * mini(quantity, slot.quantity)


static func scrap_slot(inventory: InventoryStore, slot_id: int, quantity: int, scrap_item: ItemDefinition) -> bool:
	if inventory == null or scrap_item == null:
		return false
	var slot := inventory.get_slot(slot_id)
	if not can_scrap(slot, scrap_item) or quantity <= 0 or quantity > slot.quantity:
		return false
	return inventory.exchange_slot(slot_id, quantity, scrap_item, get_output_quantity(slot, quantity))
