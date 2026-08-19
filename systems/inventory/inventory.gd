## Mutable inventory store with slot snapshots for UI safety and save serialization.
class_name InventoryStore
extends Node

signal item_added(definition: ItemDefinition, quantity: int)
signal item_removed(definition: ItemDefinition, quantity: int)
signal item_used(definition: ItemDefinition)
signal item_dropped(definition: ItemDefinition, quantity: int)
signal changed(slots: Array[ItemStack])

var _slots: Array[ItemStack] = []
var _next_slot_id := 1


func clear() -> void:
	_slots.clear()
	_next_slot_id = 1
	_emit_changed()


func add_item(definition: ItemDefinition, quantity: int = 1) -> void:
	# Ignore invalid add requests so callers can fire-and-forget safely.
	if definition == null or quantity <= 0:
		return

	var remaining := quantity
	if definition.stackable:
		# Fill partial stacks first to reduce slot churn and preserve compact inventory shape.
		for slot in _slots:
			# Skip slots for other items or full stacks.
			if slot.definition != definition or slot.quantity >= definition.max_stack:
				continue
			var space_left: int = definition.max_stack - slot.quantity
			var added_to_slot = min(remaining, space_left)
			slot.quantity += added_to_slot
			remaining -= added_to_slot
			item_added.emit(definition, added_to_slot)
			# Early exit once the full incoming quantity has been distributed.
			if remaining == 0:
				_emit_changed()
				return

		# Create as many full/new stacks as needed for any leftover quantity.
		while remaining > 0:
			var stack_size = min(remaining, max(definition.max_stack, 1))
			_slots.append(_create_slot(definition, stack_size))
			remaining -= stack_size
			item_added.emit(definition, stack_size)
	else:
		# Non-stackables allocate one slot per item instance.
		for _index in quantity:
			_slots.append(_create_slot(definition, 1))
			item_added.emit(definition, 1)

	_emit_changed()


func remove_item(definition: ItemDefinition, quantity: int = 1) -> bool:
	# Validate request and available quantity before mutating any slots.
	if definition == null or quantity <= 0 or get_quantity(definition) < quantity:
		return false
	var remaining := quantity
	# Walk backwards so removing empty slots never invalidates upcoming indices.
	for index in range(_slots.size() - 1, -1, -1):
		var slot := _slots[index]
		# Remove only from slots that contain the requested item.
		if slot.definition != definition:
			continue
		var removed_quantity = min(remaining, slot.quantity)
		slot.quantity -= removed_quantity
		remaining -= removed_quantity
		item_removed.emit(definition, removed_quantity)
		# Clean up empty stacks after decrement.
		if slot.quantity == 0:
			_slots.remove_at(index)
		# Stop once requested amount has been fully removed.
		if remaining == 0:
			break
	_emit_changed()
	return true


func has_item(definition: ItemDefinition, quantity: int = 1) -> bool:
	var total := 0
	for slot in _slots:
		# Only count slots that match the queried item resource.
		if slot.definition == definition:
			total += slot.quantity
	return total >= quantity


func get_slots() -> Array[ItemStack]:
	var snapshots: Array[ItemStack] = []
	for slot in _slots:
		snapshots.append(slot.snapshot())
	return snapshots


func get_slot(slot_id: int) -> ItemStack:
	var slot := _find_slot(slot_id)
	# Return snapshot copy to protect internal slot mutability.
	return slot.snapshot() if slot else null


func get_quantity(definition: ItemDefinition) -> int:
	var total := 0
	for slot in _slots:
		# Quantity is summed across all matching stacks.
		if slot.definition == definition:
			total += slot.quantity
	return total


func to_save_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for slot in _slots:
		# Save payload relies on resource paths to reconstruct item resources.
		if slot.definition.resource_path.is_empty():
			push_warning("Skipping inventory item without a resource path: %s" % slot.definition.display_name)
			continue
		data.append({
			"item_path": slot.definition.resource_path,
			"quantity": slot.quantity,
		})
	return data


func load_save_data(data: Array) -> void:
	_slots.clear()
	_next_slot_id = 1
	for entry in data:
		# Ignore malformed rows while preserving valid entries.
		if not entry is Dictionary:
			continue
		var item_path := str(entry.get("item_path", ""))
		var quantity := int(entry.get("quantity", 0))
		# Invalid resources are skipped so one bad entry does not discard the whole inventory.
		var item := load(item_path) as ItemDefinition if ResourceLoader.exists(item_path) else null
		if item == null or quantity <= 0:
			push_warning("Skipping invalid saved inventory entry: %s" % item_path)
			continue
		_restore_stack(item, quantity)
	_emit_changed()


func use_slot(slot_id: int, user: Node) -> bool:
	var slot := _find_slot(slot_id)
	# Use can fail because slot is missing, unusable, or use() returns false.
	if slot == null or not slot.definition.can_use(user) or not slot.definition.use(user):
		return false
	item_used.emit(slot.definition)
	# Consumables remove one item from the stack after successful use.
	if slot.definition.consumed_on_use:
		_remove_from_slot(slot_id, 1)
	return true


func drop_slot(slot_id: int, quantity: int = 1) -> bool:
	var slot := _find_slot(slot_id)
	# Drop requires an existing droppable slot and positive quantity.
	if slot == null or not slot.definition.droppable or quantity <= 0:
		return false
	var dropped_quantity = min(quantity, slot.quantity)
	var definition := slot.definition
	_remove_from_slot(slot_id, dropped_quantity)
	item_dropped.emit(definition, dropped_quantity)
	return true


func exchange_slot(slot_id: int, quantity: int, output: ItemDefinition, output_quantity: int) -> bool:
	var slot := _find_slot(slot_id)
	# Exchange aborts for invalid source slot, quantity, or output definition.
	if slot == null or quantity <= 0 or quantity > slot.quantity or output == null or output_quantity <= 0:
		return false
	_remove_from_slot(slot_id, quantity)
	add_item(output, output_quantity)
	return true


func _create_slot(definition: ItemDefinition, quantity: int) -> ItemStack:
	var slot := ItemStack.new(_next_slot_id, definition, quantity)
	_next_slot_id += 1
	return slot


func _restore_stack(definition: ItemDefinition, quantity: int) -> void:
	_slots.append(_create_slot(definition, quantity))


func _find_slot(slot_id: int) -> ItemStack:
	for slot in _slots:
		# IDs are unique, so first match is the target slot.
		if slot.id == slot_id:
			return slot
	return null


func _remove_from_slot(slot_id: int, quantity: int) -> void:
	for index in _slots.size():
		var slot := _slots[index]
		# Continue until the requested slot id is found.
		if slot.id != slot_id:
			continue
		# Slot IDs are unique, so we can mutate once and return immediately.
		var removed_quantity = min(quantity, slot.quantity)
		slot.quantity -= removed_quantity
		item_removed.emit(slot.definition, removed_quantity)
		if slot.quantity == 0:
			_slots.remove_at(index)
		_emit_changed()
		return


func _emit_changed() -> void:
	changed.emit(get_slots())
