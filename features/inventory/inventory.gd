## Mutable inventory store with slot snapshots for UI safety and save serialization.
class_name InventoryStore
extends Node

signal item_added(instance: ItemInstance)
signal item_removed(instance: ItemInstance)
signal item_used(instance: ItemInstance)
signal item_dropped(instance: ItemInstance)
signal changed(slots: Array[ItemStack])

var _slots: Array[ItemStack] = []
var _next_slot_id := 1


func clear() -> void:
	_slots.clear()
	_next_slot_id = 1
	_emit_changed()


func add_instance(instance: ItemInstance) -> void:
	if instance == null or instance.definition == null or instance.quantity <= 0:
		return

	var remaining := instance.quantity
	var definition = instance.definition
	
	if definition.stackable:
		# Fill partial stacks first
		for slot in _slots:
			if slot.instance.definition != definition or slot.instance.quantity >= definition.max_stack:
				continue
			# Note: in a true component system, you might only stack instances if their components match.
			# For now, we stack if definitions match.
			var space_left: int = definition.max_stack - slot.instance.quantity
			var added_to_slot = min(remaining, space_left)
			slot.instance.quantity += added_to_slot
			remaining -= added_to_slot
			
			var added_instance = instance.duplicate()
			added_instance.quantity = added_to_slot
			item_added.emit(added_instance)
			
			if remaining == 0:
				_emit_changed()
				return

		# Create new slots for leftovers
		while remaining > 0:
			var stack_size = min(remaining, max(definition.max_stack, 1))
			var new_inst = instance.duplicate()
			new_inst.quantity = stack_size
			_slots.append(_create_slot(new_inst))
			remaining -= stack_size
			item_added.emit(new_inst)
	else:
		# Non-stackables
		for _index in remaining:
			var new_inst = instance.duplicate()
			new_inst.quantity = 1
			_slots.append(_create_slot(new_inst))
			item_added.emit(new_inst)

	_emit_changed()


func add_item(definition: ItemDefinition, quantity: int = 1) -> void:
	add_instance(ItemInstance.new(definition, quantity))


func remove_item(definition: ItemDefinition, quantity: int = 1) -> bool:
	if definition == null or quantity <= 0 or get_quantity(definition) < quantity:
		return false
	var remaining := quantity
	for index in range(_slots.size() - 1, -1, -1):
		var slot := _slots[index]
		if slot.instance.definition != definition:
			continue
		var removed_quantity = min(remaining, slot.instance.quantity)
		slot.instance.quantity -= removed_quantity
		remaining -= removed_quantity
		
		var removed_inst = slot.instance.duplicate()
		removed_inst.quantity = removed_quantity
		item_removed.emit(removed_inst)
		
		if slot.instance.quantity == 0:
			_slots.remove_at(index)
		if remaining == 0:
			break
	_emit_changed()
	return true


func has_item(definition: ItemDefinition, quantity: int = 1) -> bool:
	return get_quantity(definition) >= quantity


func get_slots() -> Array[ItemStack]:
	var snapshots: Array[ItemStack] = []
	for slot in _slots:
		snapshots.append(slot.snapshot())
	return snapshots


func get_slot(slot_id: int) -> ItemStack:
	var slot := _find_slot(slot_id)
	return slot.snapshot() if slot else null


func get_quantity(definition: ItemDefinition) -> int:
	var total := 0
	for slot in _slots:
		if slot.instance.definition == definition:
			total += slot.instance.quantity
	return total


func to_save_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for slot in _slots:
		data.append(slot.instance.serialize())
	return data


func load_save_data(data: Array) -> void:
	_slots.clear()
	_next_slot_id = 1
	for entry in data:
		if not entry is Dictionary:
			continue
		var instance = ItemInstance.deserialize(entry)
		if instance != null:
			_slots.append(_create_slot(instance))
	_emit_changed()


func use_slot(slot_id: int, user: Node) -> bool:
	var slot := _find_slot(slot_id)
	if slot == null or not slot.instance.definition.can_use(user) or not slot.instance.definition.use(user):
		return false
	item_used.emit(slot.instance)
	if slot.instance.definition.consumed_on_use:
		_remove_from_slot(slot_id, 1)
	return true


func drop_slot(slot_id: int, quantity: int = 1) -> bool:
	var slot := _find_slot(slot_id)
	if slot == null or not slot.instance.definition.droppable or quantity <= 0:
		return false
	var dropped_quantity = min(quantity, slot.instance.quantity)
	var dropped_inst = slot.instance.duplicate()
	dropped_inst.quantity = dropped_quantity
	_remove_from_slot(slot_id, dropped_quantity)
	item_dropped.emit(dropped_inst)
	return true


func exchange_slot(slot_id: int, quantity: int, output: ItemDefinition, output_quantity: int) -> bool:
	var slot := _find_slot(slot_id)
	if slot == null or quantity <= 0 or quantity > slot.instance.quantity or output == null or output_quantity <= 0:
		return false
	_remove_from_slot(slot_id, quantity)
	add_item(output, output_quantity)
	return true


func _create_slot(instance: ItemInstance) -> ItemStack:
	var slot := ItemStack.new(_next_slot_id, instance)
	_next_slot_id += 1
	return slot


func _find_slot(slot_id: int) -> ItemStack:
	for slot in _slots:
		if slot.id == slot_id:
			return slot
	return null


func _remove_from_slot(slot_id: int, quantity: int) -> void:
	for index in _slots.size():
		var slot := _slots[index]
		if slot.id != slot_id:
			continue
		var removed_quantity = min(quantity, slot.instance.quantity)
		slot.instance.quantity -= removed_quantity
		
		var removed_inst = slot.instance.duplicate()
		removed_inst.quantity = removed_quantity
		item_removed.emit(removed_inst)
		
		if slot.instance.quantity == 0:
			_slots.remove_at(index)
		_emit_changed()
		return

func _emit_changed() -> void:
	changed.emit(get_slots())
