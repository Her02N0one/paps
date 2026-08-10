## Canonical mutable game-state store shared by runtime systems and persistence.
class_name GameState
extends Node

signal state_changed
signal person_record_changed(person_id: StringName, record: Dictionary)

const PERSON_RECORD_VERSION := 1

var current_area := ""
var global_flags: Dictionary = {}
var people: Dictionary = {}

var _areas: Dictionary = {}
# Persisted with the save so dropped-item IDs remain unique across sessions.
var _next_dynamic_id := 1
var _inventory: InventoryStore = InventoryStore.new()
var _active_people: Dictionary = {}


func _ready() -> void:
	add_child(_inventory)
	add_to_group("game_state")


func get_inventory() -> InventoryStore:
	return _inventory


func reset(initial_area: String) -> void:
	current_area = initial_area
	global_flags.clear()
	people.clear()
	_areas.clear()
	_next_dynamic_id = 1
	_active_people.clear()
	if _inventory:
		_inventory.clear()
	state_changed.emit()


func to_global_save_data() -> Dictionary:
	return {
		"current_area": current_area,
		"next_dynamic_id": _next_dynamic_id,
		"flags": global_flags.duplicate(true),
		"people": people.duplicate(true),
		"inventory": _inventory.to_save_data() if _inventory else [],
	}


func to_scene_save_data() -> Dictionary:
	return _areas.duplicate(true)


func load_save_data(global_data: Dictionary, scene_data: Dictionary) -> bool:
	var area_path := str(global_data.get("current_area", ""))
	var inventory_data = global_data.get("inventory", [])
	var flags = global_data.get("flags", {})
	var saved_people = global_data.get("people", {})
	# Reject partial payloads early; runtime expects all three sections to be coherent.
	if area_path.is_empty() or not inventory_data is Array or not flags is Dictionary or not saved_people is Dictionary:
		return false
	current_area = area_path
	_next_dynamic_id = maxi(int(global_data.get("next_dynamic_id", 1)), 1)
	global_flags = flags.duplicate(true)
	people.clear()
	# Normalize each saved person record so runtime code can rely on one schema.
	for person_id in saved_people:
		people[person_id] = _normalize_person_record(saved_people[person_id], "")
	_areas = scene_data.duplicate(true)
	_active_people.clear()
	# Inventory state is optional in tests, so guard before load.
	if _inventory:
		_inventory.load_save_data(inventory_data)
	state_changed.emit()
	return true


func register_person_if_missing(
	person_id: StringName,
	area_path: String,
	person_scene_path: String,
	transform: Transform3D,
	profile: Dictionary = {}
) -> void:
	# One-time registration keeps authored spawn and persisted spawn paths from duplicating records.
	# Empty IDs are invalid and existing IDs are intentionally left untouched.
	if person_id.is_empty() or people.has(person_id):
		return
	var new_record := _create_person_record(area_path, person_scene_path, transform, profile)
	people[person_id] = new_record
	person_record_changed.emit(person_id, new_record.duplicate(true))
	state_changed.emit()


func get_person_record(person_id: StringName) -> Dictionary:
	var record: Variant = people.get(person_id, {})
	# Non-dictionary records are treated as absent/corrupt.
	if not record is Dictionary:
		return {}
	return _normalize_person_record(record, "")


func get_people_in_area(area_path: String, include_disabled: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for person_id in people:
		var record := _normalize_person_record(people[person_id], "")
		# Filter by area first, then optionally by enabled state.
		if str(record.get("area_path", "")) != area_path:
			continue
		# Default query hides disabled actors unless explicitly requested.
		if not include_disabled and not bool(record.get("enabled", true)):
			continue
		result[person_id] = record
	return result


func update_person_record(
	person_id: StringName,
	area_path: String,
	transform: Transform3D,
	person_scene_path: String,
	profile: Dictionary = {}
) -> void:
	# Person identity is mandatory for all record updates.
	if person_id.is_empty():
		return
	var previous := get_person_record(person_id)
	var next_record := _create_person_record(area_path, person_scene_path, transform, profile)
	if not previous.is_empty():
		# Preserve runtime toggles and stateful fields unless explicitly overridden.
		next_record["enabled"] = previous.get("enabled", true)
		next_record["state"] = (previous.get("state", {}) as Dictionary).duplicate(true)
		next_record["flags"] = (previous.get("flags", {}) as Dictionary).duplicate(true)
		# Keep previous profile when caller does not provide replacement profile data.
		if profile.is_empty():
			next_record["profile"] = (previous.get("profile", {}) as Dictionary).duplicate(true)
	# Skip signaling/autosave churn when record is unchanged.
	if previous == next_record:
		return
	people[person_id] = next_record
	person_record_changed.emit(person_id, next_record.duplicate(true))
	state_changed.emit()


func set_person_enabled(person_id: StringName, enabled: bool) -> void:
	# Ignore requests without a valid target identity.
	if person_id.is_empty():
		return
	var previous := get_person_record(person_id)
	# Missing records are not auto-created by enable toggles.
	if previous.is_empty():
		return
	# Avoid emitting writes/signals when enabled state is already in desired value.
	if bool(previous.get("enabled", true)) == enabled:
		return
	previous["enabled"] = enabled
	previous["last_seen_unix"] = int(Time.get_unix_time_from_system())
	people[person_id] = previous
	person_record_changed.emit(person_id, previous.duplicate(true))
	state_changed.emit()


func is_person_enabled(person_id: StringName) -> bool:
	var record := get_person_record(person_id)
	# Unknown person IDs are treated as unavailable/disabled.
	if record.is_empty():
		return false
	return bool(record.get("enabled", true))


func set_person_state_value(person_id: StringName, key: StringName, value: Variant) -> void:
	# Both person and state key must be valid.
	if person_id.is_empty() or key.is_empty():
		return
	var record := get_person_record(person_id)
	# Avoid mutating absent records.
	if record.is_empty():
		return
	var state := record.get("state", {}) as Dictionary
	# No-op writes are intentionally skipped to reduce autosave churn.
	if state.get(key) == value:
		return
	state[key] = value
	record["state"] = state
	record["last_seen_unix"] = int(Time.get_unix_time_from_system())
	people[person_id] = record
	person_record_changed.emit(person_id, record.duplicate(true))
	state_changed.emit()


func get_person_state_value(person_id: StringName, key: StringName, default_value: Variant = null) -> Variant:
	# Invalid lookup returns caller-provided default.
	var record := get_person_record(person_id)
	if record.is_empty() or key.is_empty():
		return default_value
	var state := record.get("state", {}) as Dictionary
	return state.get(key, default_value)


func set_person_flag(person_id: StringName, flag: StringName, value: bool) -> void:
	# Reject malformed flag updates early.
	if person_id.is_empty() or flag.is_empty():
		return
	var record := get_person_record(person_id)
	# Flag writes require an existing record.
	if record.is_empty():
		return
	var flags := record.get("flags", {}) as Dictionary
	# Flag writes mirror state-value behavior: mutate only on actual change.
	if bool(flags.get(flag, false)) == value:
		return
	flags[flag] = value
	record["flags"] = flags
	record["last_seen_unix"] = int(Time.get_unix_time_from_system())
	people[person_id] = record
	person_record_changed.emit(person_id, record.duplicate(true))
	state_changed.emit()


func get_person_flag(person_id: StringName, flag: StringName, default_value: bool = false) -> bool:
	# Fall back for unknown person or invalid flag key.
	var record := get_person_record(person_id)
	if record.is_empty() or flag.is_empty():
		return default_value
	var flags := record.get("flags", {}) as Dictionary
	return bool(flags.get(flag, default_value))


func register_active_person(person_id: StringName, person: Node) -> bool:
	# Active registry only accepts non-empty id and live node references.
	if person_id.is_empty() or person == null:
		return false
	var active_ref := _active_people.get(person_id) as WeakRef
	var active: Object = active_ref.get_ref() if active_ref else null
	# Reject a second live owner for the same id unless the previous ref is stale.
	if active and is_instance_valid(active) and active != person:
		return false
	_active_people[person_id] = weakref(person)
	return true


func unregister_active_person(person_id: StringName, person: Node) -> void:
	# Ignore invalid unregistration requests.
	if person_id.is_empty() or person == null:
		return
	var active_ref := _active_people.get(person_id) as WeakRef
	# Nothing to remove when registry has no entry.
	if active_ref == null:
		return
	var active: Object = active_ref.get_ref()
	# Clear stale refs and matching owner refs.
	if active == null or active == person:
		_active_people.erase(person_id)


func set_global_flag(flag: StringName, value: Variant) -> void:
	# Global flags participate in autosave; no-op updates are suppressed.
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
	# Empty persistent IDs are never considered collected.
	if persistent_id.is_empty():
		return false
	var area := _ensure_area(area_path)
	return persistent_id in area.removed_static_pickups


func collect_static_pickup(area_path: String, persistent_id: String) -> void:
	# Ignore malformed collection requests.
	if persistent_id.is_empty():
		return
	var area := _ensure_area(area_path)
	# Insert only once; duplicate collection should be a no-op.
	if persistent_id not in area.removed_static_pickups:
		area.removed_static_pickups.append(persistent_id)
		state_changed.emit()


func add_dynamic_pickup(
	area_path: String,
	data: ItemData,
	quantity: int,
	transform: Transform3D,
	instance_overrides: Dictionary = {}
) -> String:
	# Dynamic pickups require persistent item path + positive quantity to be recoverable.
	if data == null or data.resource_path.is_empty() or quantity <= 0:
		return ""
	var dynamic_id := "drop_%d" % _next_dynamic_id
	_next_dynamic_id += 1
	var area := _ensure_area(area_path)
	var dynamic_record := {
		"item_path": data.resource_path,
		"quantity": quantity,
		"transform": transform,
	}
	if not instance_overrides.is_empty():
		dynamic_record["instance_overrides"] = instance_overrides.duplicate(true)
	area.dynamic_pickups[dynamic_id] = dynamic_record
	state_changed.emit()
	return dynamic_id


func set_person_instance_overrides(person_id: StringName, instance_overrides: Dictionary) -> void:
	# Target identity must exist to mutate instance overrides.
	if person_id.is_empty():
		return
	var record := get_person_record(person_id)
	# Unknown record means nothing to update.
	if record.is_empty():
		return
	var normalized := instance_overrides.duplicate(true) if instance_overrides != null else {}
	# Skip re-write when overrides are unchanged to avoid noisy persistence updates.
	if record.get("instance_overrides", {}) == normalized:
		return
	record["instance_overrides"] = normalized
	record["last_seen_unix"] = int(Time.get_unix_time_from_system())
	people[person_id] = record
	person_record_changed.emit(person_id, record.duplicate(true))
	state_changed.emit()


func remove_dynamic_pickup(area_path: String, dynamic_id: String) -> void:
	var area := _ensure_area(area_path)
	# Emit only when removal actually happened.
	if area.dynamic_pickups.erase(dynamic_id):
		state_changed.emit()


func get_dynamic_pickups(area_path: String) -> Dictionary:
	return _ensure_area(area_path).dynamic_pickups.duplicate(true)


func _ensure_area(area_path: String) -> Dictionary:
	# Area buckets are created lazily because authored levels may be visited in any order.
	if not _areas.has(area_path):
		_areas[area_path] = {
			"removed_static_pickups": [],
			"dynamic_pickups": {},
		}
	return _areas[area_path]


func _create_person_record(
	area_path: String,
	person_scene_path: String,
	transform: Transform3D,
	profile: Dictionary = {}
) -> Dictionary:
	return {
		"version": PERSON_RECORD_VERSION,
		"area_path": area_path,
		"scene_path": person_scene_path,
		"transform": transform,
		"enabled": true,
		"state": {},
		"flags": {},
		"instance_overrides": {},
		"profile": profile.duplicate(true),
		"last_seen_unix": int(Time.get_unix_time_from_system()),
	}


func _normalize_person_record(raw_record: Variant, fallback_area: String) -> Dictionary:
	# Corrupt record types are discarded instead of crashing normalization.
	if not raw_record is Dictionary:
		return {}
	var record := raw_record as Dictionary
	var fallback_transform := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var normalized := _create_person_record(
		str(record.get("area_path", fallback_area)),
		str(record.get("scene_path", "")),
		record.get("transform", fallback_transform) if typeof(record.get("transform", null)) == TYPE_TRANSFORM3D else fallback_transform,
		record.get("profile", {}) if record.get("profile", {}) is Dictionary else {}
	)
	# Copy only validated optional sections so malformed saves degrade gracefully.
	normalized["version"] = maxi(int(record.get("version", 0)), PERSON_RECORD_VERSION)
	normalized["enabled"] = bool(record.get("enabled", true))
	var state_raw = record.get("state", {})
	# Copy optional dictionaries only when type matches expected schema.
	if state_raw is Dictionary:
		normalized["state"] = (state_raw as Dictionary).duplicate(true)
	var flags_raw = record.get("flags", {})
	if flags_raw is Dictionary:
		normalized["flags"] = (flags_raw as Dictionary).duplicate(true)
	var instance_overrides_raw = record.get("instance_overrides", {})
	if instance_overrides_raw is Dictionary:
		normalized["instance_overrides"] = (instance_overrides_raw as Dictionary).duplicate(true)
	normalized["last_seen_unix"] = int(record.get("last_seen_unix", int(Time.get_unix_time_from_system())))
	return normalized
