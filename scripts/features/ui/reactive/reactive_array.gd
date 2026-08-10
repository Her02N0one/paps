## Array wrapper that emits one reactive change signal for each mutation API call.
class_name ReactiveArray
extends Reactive

var value: Array = []


func _init(initial: Array = [], initial_owner: Reactive = null) -> void:
	value = initial.duplicate()
	reactive_owner = initial_owner


func set_array(next: Array) -> void:
	# Duplicate to keep external callers from mutating internal state by reference.
	value = next.duplicate()
	notify_reactive_changed()


func append(item: Variant) -> void:
	value.append(item)
	notify_reactive_changed()


func append_array(items: Array) -> void:
	value.append_array(items)
	notify_reactive_changed()


func erase(item: Variant) -> bool:
	var had_item := value.has(item)
	if not had_item:
		# Preserve false result without emitting a noisy no-op change.
		return false
	value.erase(item)
	notify_reactive_changed()
	return true


func clear() -> void:
	if value.is_empty():
		return
	value.clear()
	notify_reactive_changed()


func insert(index: int, item: Variant) -> void:
	value.insert(index, item)
	notify_reactive_changed()


func remove_at(index: int) -> void:
	if index < 0 or index >= value.size():
		return
	value.remove_at(index)
	notify_reactive_changed()


func pop_back() -> Variant:
	if value.is_empty():
		return null
	var last_index := value.size() - 1
	var removed: Variant = value[last_index]
	value.remove_at(last_index)
	notify_reactive_changed()
	return removed


func pop_at(index: int) -> Variant:
	if index < 0 or index >= value.size():
		return null
	var removed: Variant = value[index]
	value.remove_at(index)
	notify_reactive_changed()
	return removed
