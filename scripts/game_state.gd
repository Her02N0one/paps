extends Node

signal state_changed

var current_area := ""
var global_flags: Dictionary = {}

var _areas: Dictionary = {}
var _next_dynamic_id := 1


func reset(initial_area: String) -> void:
	current_area = initial_area
	global_flags.clear()
	_areas.clear()
	_next_dynamic_id = 1
	Inventory.clear()
	state_changed.emit()


func to_global_save_data() -> Dictionary:
	return {
		"current_area": current_area,
		"next_dynamic_id": _next_dynamic_id,
		"flags": global_flags.duplicate(true),
		"inventory": Inventory.to_save_data(),
	}


func to_scene_save_data() -> Dictionary:
	return _areas.duplicate(true)


func load_save_data(global_data: Dictionary, scene_data: Dictionary) -> bool:
	var area_path := str(global_data.get("current_area", ""))
	var inventory_data = global_data.get("inventory", [])
	var flags = global_data.get("flags", {})
	if area_path.is_empty() or not inventory_data is Array or not flags is Dictionary:
		return false
	current_area = area_path
	_next_dynamic_id = maxi(int(global_data.get("next_dynamic_id", 1)), 1)
	global_flags = flags.duplicate(true)
	_areas = scene_data.duplicate(true)
	Inventory.load_save_data(inventory_data)
	state_changed.emit()
	return true


func set_global_flag(flag: StringName, value: Variant) -> void:
	if global_flags.get(flag) == value:
		return
	global_flags[flag] = value
	state_changed.emit()


func get_global_flag(flag: StringName, default_value: Variant = null) -> Variant:
	return global_flags.get(flag, default_value)


func enter_area(area_path: String) -> void:
	current_area = area_path
	_ensure_area(area_path)
	state_changed.emit()


func is_static_pickup_collected(area_path: String, persistent_id: String) -> bool:
	if persistent_id.is_empty():
		return false
	var area := _ensure_area(area_path)
	return persistent_id in area.removed_static_pickups


func collect_static_pickup(area_path: String, persistent_id: String) -> void:
	if persistent_id.is_empty():
		return
	var area := _ensure_area(area_path)
	if persistent_id not in area.removed_static_pickups:
		area.removed_static_pickups.append(persistent_id)
		state_changed.emit()


func add_dynamic_pickup(area_path: String, data: ItemData, quantity: int, transform: Transform3D) -> String:
	if data == null or data.resource_path.is_empty() or quantity <= 0:
		return ""
	var dynamic_id := "drop_%d" % _next_dynamic_id
	_next_dynamic_id += 1
	var area := _ensure_area(area_path)
	area.dynamic_pickups[dynamic_id] = {
		"item_path": data.resource_path,
		"quantity": quantity,
		"transform": transform,
	}
	state_changed.emit()
	return dynamic_id


func remove_dynamic_pickup(area_path: String, dynamic_id: String) -> void:
	var area := _ensure_area(area_path)
	if area.dynamic_pickups.erase(dynamic_id):
		state_changed.emit()


func get_dynamic_pickups(area_path: String) -> Dictionary:
	return _ensure_area(area_path).dynamic_pickups.duplicate(true)


func _ensure_area(area_path: String) -> Dictionary:
	if not _areas.has(area_path):
		_areas[area_path] = {
			"removed_static_pickups": [],
			"dynamic_pickups": {},
		}
	return _areas[area_path]