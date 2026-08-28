## Handles interfacing with the GameState to save and load PersonActor state.
class_name PersonPersistenceSystem
extends Node

var _game_state: GameState
var _resolved_person_id: StringName
var _is_registered_active := false
var _persist_on_exit := false


func register_and_restore(actor: PersonActor) -> bool:
	_game_state = ServiceRegistry.game_state
	_resolved_person_id = _resolve_person_id(actor)
	if _resolved_person_id.is_empty():
		push_error("Person '%s' needs a non-empty person_id or node name." % actor.name)
		return false
	if not _game_state.register_active_person(_resolved_person_id, actor):
		return false
	_is_registered_active = true

	_game_state.register_person_if_missing(
		_resolved_person_id,
		_game_state.current_area,
		actor.scene_file_path,
		actor.global_transform,
		_build_profile(actor)
	)
	var record := _game_state.get_person_record(_resolved_person_id)
	if not bool(record.get("enabled", true)):
		return false
	_apply_profile_from_record(actor, record)
	var record_area := str(record.get("area_path", ""))
	if not record_area.is_empty() and record_area != _game_state.current_area:
		return false

	var saved_transform = record.get("transform")
	if actor.persist_transform and typeof(saved_transform) == TYPE_TRANSFORM3D:
		actor.global_transform = saved_transform
	_persist_on_exit = true
	return true


func release_persistence(actor: PersonActor) -> void:
	if _is_registered_active:
		_game_state.unregister_active_person(_resolved_person_id, actor)
	if _persist_on_exit:
		_game_state.update_person_record(
			_resolved_person_id,
			_game_state.current_area,
			actor.global_transform,
			actor.scene_file_path,
			_build_profile(actor)
		)


func persist_current_transform_if_active(actor: PersonActor) -> void:
	if not _is_registered_active:
		return
	_game_state.update_person_record(
		_resolved_person_id,
		_game_state.current_area,
		actor.global_transform,
		actor.scene_file_path,
		_build_profile(actor)
	)


func set_person_area(actor: PersonActor, target_area_path: String, target_transform: Transform3D) -> void:
	_game_state.set_person_enabled(_resolved_person_id, true)
	_game_state.update_person_record(_resolved_person_id, target_area_path, target_transform, actor.scene_file_path, _build_profile(actor))
	if target_area_path != _game_state.current_area:
		_persist_on_exit = false
		actor.queue_free()


func set_person_enabled(actor: PersonActor, enabled: bool) -> void:
	_game_state.set_person_enabled(_resolved_person_id, enabled)
	if not enabled:
		_persist_on_exit = false
		actor.queue_free()


func is_person_enabled() -> bool:
	return _game_state.is_person_enabled(_resolved_person_id)


func set_person_state_value(key: StringName, value: Variant) -> void:
	_game_state.set_person_state_value(_resolved_person_id, key, value)


func get_person_state_value(key: StringName, default_value: Variant = null) -> Variant:
	return _game_state.get_person_state_value(_resolved_person_id, key, default_value)


func set_person_flag(flag: StringName, value: bool) -> void:
	_game_state.set_person_flag(_resolved_person_id, flag, value)


func get_person_flag(flag: StringName, default_value: bool = false) -> bool:
	return _game_state.get_person_flag(_resolved_person_id, flag, default_value)


func get_person_id(actor: PersonActor) -> StringName:
	return _resolved_person_id if not _resolved_person_id.is_empty() else _resolve_person_id(actor)


func apply_profile(actor: PersonActor, profile: Dictionary) -> void:
	_apply_profile_from_record(actor, {"profile": profile})


func _resolve_person_id(actor: PersonActor) -> StringName:
	if not actor.person_id.is_empty():
		return actor.person_id
	return StringName(actor.name)


func _build_profile(actor: PersonActor) -> Dictionary:
	return {
		"definition_path": actor.definition.resource_path if actor.definition and not actor.definition.resource_path.is_empty() else "",
		"current_health": actor.health_component.current_health if actor.health_component != null else -1.0,
	}


func _apply_profile_from_record(actor: PersonActor, record: Dictionary) -> void:
	var profile_raw = record.get("profile", {})
	if not profile_raw is Dictionary:
		actor.refresh_person_profile()
		return
	var profile := profile_raw as Dictionary
	var definition_path := str(profile.get("definition_path", ""))
	if not definition_path.is_empty() and ResourceLoader.exists(definition_path):
		var loaded := load(definition_path)
		if loaded is PersonDefinition:
			actor.definition = loaded
	actor.refresh_person_profile()

	_restore_persisted_health(actor, profile)


func _restore_persisted_health(actor: PersonActor, profile: Dictionary) -> void:
	if actor.health_component == null:
		return
	var persisted_health := float(profile.get("current_health", -1.0))
	if persisted_health < 0.0:
		return
	actor.health_component.current_health = clampf(persisted_health, 0.0, actor.health_component.max_health)
	actor.health_component.health_changed.emit(actor.health_component.current_health, actor.health_component.max_health)
