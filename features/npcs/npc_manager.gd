extends Node
class_name NPCManager

const PERSON_RECORD_VERSION := 2

var people: Dictionary = {}
var _active_people: Dictionary = {}

func _ready() -> void:
	pass

func configure_hooks(save_manager: SaveManager) -> void:
	if not save_manager.about_to_save.is_connected(_on_about_to_save):
		save_manager.about_to_save.connect(_on_about_to_save)
	if not save_manager.game_loaded.is_connected(_on_game_loaded):
		save_manager.game_loaded.connect(_on_game_loaded)

func _on_about_to_save() -> void:
	var gs = ServiceRegistry.game_state
	if gs:
		gs.global_flags["npc_manager_people"] = people.duplicate(true)

func _on_game_loaded() -> void:
	var gs = ServiceRegistry.game_state
	if gs and gs.global_flags.has("npc_manager_people"):
		var saved_people = gs.global_flags["npc_manager_people"]
		people.clear()
		for person_id in saved_people:
			people[person_id] = _normalize_person_record(saved_people[person_id], "")
		_active_people.clear()
		gs.state_changed.emit()

func register_person_if_missing(person_id: StringName, area_path: String, person_scene_path: String, transform: Transform3D, profile: Dictionary = {}) -> void:
	if person_id.is_empty() or people.has(person_id):
		return
	var new_record := _create_person_record(area_path, person_scene_path, transform, profile)
	people[person_id] = new_record
	_emit_state_changed()

func get_person_record(person_id: StringName) -> Dictionary:
	var record: Variant = people.get(person_id, {})
	if not record is Dictionary:
		return {}
	return _normalize_person_record(record, "")

func get_people_in_area(area_path: String, include_disabled: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for person_id in people:
		var record := _normalize_person_record(people[person_id], "")
		if str(record.get("area_path", "")) != area_path:
			continue
		if not include_disabled and not bool(record.get("enabled", true)):
			continue
		result[person_id] = record
	return result

func update_person_record(person_id: StringName, area_path: String, transform: Transform3D, person_scene_path: String, profile: Dictionary = {}) -> void:
	if person_id.is_empty():
		return
	var previous := get_person_record(person_id)
	var next_record := _create_person_record(area_path, person_scene_path, transform, profile)
	if not previous.is_empty():
		next_record["enabled"] = previous.get("enabled", true)
		next_record["state"] = (previous.get("state", {}) as Dictionary).duplicate(true)
		next_record["flags"] = (previous.get("flags", {}) as Dictionary).duplicate(true)
		next_record["natural_expiry_unix"] = previous.get("natural_expiry_unix", 0)
		if profile.is_empty():
			next_record["profile"] = (previous.get("profile", {}) as Dictionary).duplicate(true)
			next_record["disposition"] = previous.get("disposition", "")
			next_record["current_health"] = previous.get("current_health", -1.0)
	if previous == next_record:
		return
	people[person_id] = next_record
	_emit_state_changed()

func set_person_enabled(person_id: StringName, enabled: bool) -> void:
	if person_id.is_empty():
		return
	var previous := get_person_record(person_id)
	if previous.is_empty() or bool(previous.get("enabled", true)) == enabled:
		return
	previous["enabled"] = enabled
	previous["last_seen_unix"] = int(Time.get_unix_time_from_system())
	people[person_id] = previous
	_emit_state_changed()

func is_person_enabled(person_id: StringName) -> bool:
	var record := get_person_record(person_id)
	if record.is_empty():
		return false
	return bool(record.get("enabled", true))

func set_person_state_value(person_id: StringName, key: StringName, value: Variant) -> void:
	if person_id.is_empty() or key.is_empty():
		return
	var record := get_person_record(person_id)
	if record.is_empty():
		return
	var state := record.get("state", {}) as Dictionary
	if state.get(key) == value:
		return
	state[key] = value
	record["state"] = state
	record["last_seen_unix"] = int(Time.get_unix_time_from_system())
	people[person_id] = record
	_emit_state_changed()

func get_person_state_value(person_id: StringName, key: StringName, default_value: Variant = null) -> Variant:
	var record := get_person_record(person_id)
	if record.is_empty() or key.is_empty():
		return default_value
	var state := record.get("state", {}) as Dictionary
	return state.get(key, default_value)

func set_person_flag(person_id: StringName, flag: StringName, value: bool) -> void:
	if person_id.is_empty() or flag.is_empty():
		return
	var record := get_person_record(person_id)
	if record.is_empty():
		return
	var flags := record.get("flags", {}) as Dictionary
	if bool(flags.get(flag, false)) == value:
		return
	flags[flag] = value
	record["flags"] = flags
	record["last_seen_unix"] = int(Time.get_unix_time_from_system())
	people[person_id] = record
	_emit_state_changed()

func get_person_flag(person_id: StringName, flag: StringName, default_value: bool = false) -> bool:
	var record := get_person_record(person_id)
	if record.is_empty() or flag.is_empty():
		return default_value
	var flags := record.get("flags", {}) as Dictionary
	return bool(flags.get(flag, default_value))

func register_active_person(person_id: StringName, person: Node) -> bool:
	if person_id.is_empty() or person == null:
		return false
	var active_ref := _active_people.get(person_id) as WeakRef
	var active: Object = active_ref.get_ref() if active_ref else null
	if active and is_instance_valid(active) and active != person:
		return false
	_active_people[person_id] = weakref(person)
	return true

func unregister_active_person(person_id: StringName, person: Node) -> void:
	if person_id.is_empty() or person == null:
		return
	var active_ref := _active_people.get(person_id) as WeakRef
	if active_ref == null:
		return
	var active: Object = active_ref.get_ref()
	if active == null or active == person:
		_active_people.erase(person_id)

func _create_person_record(area_path: String, person_scene_path: String, transform: Transform3D, profile: Dictionary = {}) -> Dictionary:
	return {
		"version": PERSON_RECORD_VERSION,
		"area_path": area_path,
		"scene_path": person_scene_path,
		"transform": transform,
		"enabled": true,
		"is_hostile": bool(profile.get("is_hostile", false)),
		"current_health": float(profile.get("current_health", -1.0)),
		"natural_expiry_unix": 0,
		"state": {},
		"flags": {},
		"profile": profile.duplicate(true),
		"last_seen_unix": int(Time.get_unix_time_from_system()),
	}

func _normalize_person_record(raw_record: Variant, fallback_area: String) -> Dictionary:
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
	normalized["version"] = maxi(int(record.get("version", 0)), PERSON_RECORD_VERSION)
	normalized["enabled"] = bool(record.get("enabled", true))
	normalized["natural_expiry_unix"] = int(record.get("natural_expiry_unix", 0))
	var state_raw = record.get("state", {})
	if state_raw is Dictionary:
		normalized["state"] = (state_raw as Dictionary).duplicate(true)
	var flags_raw = record.get("flags", {})
	if flags_raw is Dictionary:
		normalized["flags"] = (flags_raw as Dictionary).duplicate(true)
	normalized["last_seen_unix"] = int(record.get("last_seen_unix", int(Time.get_unix_time_from_system())))
	return normalized

func _emit_state_changed() -> void:
	if ServiceRegistry.game_state:
		ServiceRegistry.game_state.state_changed.emit()
