@tool
## Persisted NPC actor with editor preview support and runtime identity/clone guards.
class_name PersonActor
extends CharacterBody3D

const PERSON_DEFINITION_SCRIPT := preload("res://scripts/features/world/person_definition.gd")
const PERSON_ACTOR_EDITOR_ADAPTER_SCRIPT := preload("res://scripts/tools/person_actor_editor_adapter.gd")

signal person_profile_changed(actor: PersonActor)
signal person_transform_changed(actor: PersonActor)

@export var person_id: StringName
@export var persist_transform := true
var _definition: Resource
@export var definition: Resource:
	get:
		return _definition
	set(value):
		_disconnect_definition_changed(_definition)
		_definition = value
		_connect_definition_changed(_definition)
		if Engine.is_editor_hint():
			_apply_definition_to_children()

var _game_state: GameState
var _resolved_person_id: StringName
var _is_registered_active := false
var _persist_on_exit := false
var _editor_adapter: Variant


func _connect_definition_changed(resource: Resource) -> void:
	# Null resource means there is nothing to observe.
	if resource == null:
		return
	# Connect once even if setter is called repeatedly.
	if not resource.changed.is_connected(_on_definition_changed):
		resource.changed.connect(_on_definition_changed)


func _disconnect_definition_changed(resource: Resource) -> void:
	# Nothing to disconnect when resource is absent.
	if resource == null:
		return
	# Guard prevents disconnect errors when signal was never connected.
	if resource.changed.is_connected(_on_definition_changed):
		resource.changed.disconnect(_on_definition_changed)


func _on_definition_changed() -> void:
	_apply_definition_to_children()
	# Editor adapter mirrors runtime visual updates in the inspector preview.
	if _editor_adapter != null:
		_editor_adapter.call("on_definition_changed")


func _ready() -> void:
	_connect_definition_changed(_definition)
	if Engine.is_editor_hint():
		# Editor mode uses polling adapter; runtime persistence wiring is skipped.
		_editor_adapter = PERSON_ACTOR_EDITOR_ADAPTER_SCRIPT.new()
		_editor_adapter.call("enter_editor_mode", self)
		return

	_game_state = get_tree().get_first_node_in_group("game_state") as GameState
	if _game_state == null:
		push_warning("Person '%s' has no game_state service; persistence and clone guards are disabled." % name)
		return

	_resolved_person_id = _resolve_person_id()
	if _resolved_person_id.is_empty():
		# Identity is required for persistence and duplicate-instance protection.
		push_error("Person '%s' needs a non-empty person_id or node name." % name)
		queue_free()
		return

	if not _game_state.register_active_person(_resolved_person_id, self):
		# Another live instance already owns this identity, so this one is a clone.
		queue_free()
		return
	_is_registered_active = true

	_game_state.register_person_if_missing(
		_resolved_person_id,
		_game_state.current_area,
		scene_file_path,
		global_transform,
		_build_profile()
	)
	var record := _game_state.get_person_record(_resolved_person_id)
	if not bool(record.get("enabled", true)):
		# Disabled records stay persisted but do not instantiate live actors.
		queue_free()
		return
	_apply_profile_from_record(record)
	var record_area := str(record.get("area_path", ""))
	# Empty area is tolerated, but mismatched explicit area means this is the wrong map.
	if not record_area.is_empty() and record_area != _game_state.current_area:
		# Record points to another area; avoid cross-area duplicate actor presence.
		queue_free()
		return

	var saved_transform = record.get("transform")
	if persist_transform and typeof(saved_transform) == TYPE_TRANSFORM3D:
		# Persisted transform wins for continuity when actor re-enters an area.
		global_transform = saved_transform
	_persist_on_exit = true


func _process(_delta: float) -> void:
	# Runtime mode does not use editor adapter polling.
	if _editor_adapter == null:
		return
	_editor_adapter.call("tick")


func _exit_tree() -> void:
	_disconnect_definition_changed(_definition)
	_editor_adapter = null
	# Release active-owner claim when this actor leaves the scene tree.
	if _game_state and _is_registered_active:
		_game_state.unregister_active_person(_resolved_person_id, self)
	if _game_state and _persist_on_exit:
		# Final transform/profile writeback only when this instance still owns persistence.
		_game_state.update_person_record(
			_resolved_person_id,
			_game_state.current_area,
			global_transform,
			scene_file_path,
			_build_profile()
		)


func has_person_definition() -> bool:
	return definition != null


func get_person_definition() -> PersonDefinition:
	return definition as PersonDefinition


func refresh_person_profile() -> void:
	_apply_definition_to_children()
	person_profile_changed.emit(self)


func set_person_speaker_name(value: String) -> void:
	var current_definition := _ensure_person_definition()
	current_definition.speaker_name = value
	refresh_person_profile()


func set_person_opening_text(value: String) -> void:
	var current_definition := _ensure_person_definition()
	current_definition.opening_text = value
	refresh_person_profile()


func set_person_conversation(value: DialogueConversation) -> void:
	var current_definition := _ensure_person_definition()
	current_definition.conversation = value
	refresh_person_profile()


func set_person_portrait_texture(value: Texture2D) -> void:
	var current_definition := _ensure_person_definition()
	current_definition.portrait_texture = value
	refresh_person_profile()


func set_person_height_meters(value: float) -> void:
	var current_definition := _ensure_person_definition()
	current_definition.height_meters = maxf(value, 0.01)
	refresh_person_profile()


func set_person_sprite_scale(value: Vector3) -> void:
	var current_definition := _ensure_person_definition()
	current_definition.sprite_scale = value
	refresh_person_profile()


func get_person_visual_height_meters() -> float:
	var sprite := get_node_or_null("Sprite3D") as Sprite3D
	# Height cannot be computed without sprite and texture.
	if sprite == null or sprite.texture == null:
		return 0.0
	return sprite.pixel_size * float(sprite.texture.get_height()) * sprite.scale.y


func teleport_person_to(position_world: Vector3) -> void:
	global_position = position_world
	_persist_current_transform_if_active()
	person_transform_changed.emit(self)


func teleport_person_transform(transform_world: Transform3D) -> void:
	global_transform = transform_world
	_persist_current_transform_if_active()
	person_transform_changed.emit(self)


func face_person_towards(target_world: Vector3) -> void:
	# Skip no-op rotate when already facing the same position.
	if global_position.is_equal_approx(target_world):
		return
	look_at(target_world, Vector3.UP, true)
	_persist_current_transform_if_active()
	person_transform_changed.emit(self)


func set_person_area(target_area_path: String, target_transform: Transform3D = global_transform) -> void:
	# Area transfer requires persistence identity and game-state service.
	if _game_state == null or _resolved_person_id.is_empty():
		return
	_game_state.set_person_enabled(_resolved_person_id, true)
	_game_state.update_person_record(_resolved_person_id, target_area_path, target_transform, scene_file_path, _build_profile())
	if target_area_path != _game_state.current_area:
		# Prevent _exit_tree from writing the current area's transform back over the destination record.
		_persist_on_exit = false
		queue_free()


func set_person_enabled(enabled: bool) -> void:
	# Cannot toggle without a resolved persisted identity.
	if _game_state == null or _resolved_person_id.is_empty():
		return
	_game_state.set_person_enabled(_resolved_person_id, enabled)
	# Disabled people are removed from the live world immediately.
	if not enabled:
		_persist_on_exit = false
		queue_free()


func is_person_enabled() -> bool:
	# Default to true when persistence service is unavailable.
	if _game_state == null or _resolved_person_id.is_empty():
		return true
	return _game_state.is_person_enabled(_resolved_person_id)


func set_person_state_value(key: StringName, value: Variant) -> void:
	# Guard null service and missing identity.
	if _game_state == null or _resolved_person_id.is_empty():
		return
	_game_state.set_person_state_value(_resolved_person_id, key, value)


func get_person_state_value(key: StringName, default_value: Variant = null) -> Variant:
	# Return fallback when persisted identity is unavailable.
	if _game_state == null or _resolved_person_id.is_empty():
		return default_value
	return _game_state.get_person_state_value(_resolved_person_id, key, default_value)


func set_person_flag(flag: StringName, value: bool) -> void:
	# Flag writes depend on game-state identity mapping.
	if _game_state == null or _resolved_person_id.is_empty():
		return
	_game_state.set_person_flag(_resolved_person_id, flag, value)


func get_person_flag(flag: StringName, default_value: bool = false) -> bool:
	# Gracefully fall back when persistence context is unavailable.
	if _game_state == null or _resolved_person_id.is_empty():
		return default_value
	return _game_state.get_person_flag(_resolved_person_id, flag, default_value)


func get_person_id() -> StringName:
	# Use persisted identity when resolved, fallback to deterministic local resolve.
	return _resolved_person_id if not _resolved_person_id.is_empty() else _resolve_person_id()


func apply_profile(profile: Dictionary) -> void:
	_apply_profile_from_record({"profile": profile})


func _resolve_person_id() -> StringName:
	# Explicit ID always wins over node-name fallback.
	if not person_id.is_empty():
		return person_id
	# Node names are stable for authored scene instances and provide a sane fallback.
	return StringName(name)


func _ensure_person_definition() -> PersonDefinition:
	# Reuse existing typed definition when available.
	if definition is PersonDefinition:
		return definition as PersonDefinition
	var created := PersonDefinition.new()
	definition = created
	return created


func _persist_current_transform_if_active() -> void:
	# Persist transform only while this actor still owns the active-person lock.
	if _game_state == null or _resolved_person_id.is_empty() or not _is_registered_active:
		return
	_game_state.update_person_record(
		_resolved_person_id,
		_game_state.current_area,
		global_transform,
		scene_file_path,
		_build_profile()
	)


func _build_profile() -> Dictionary:
	var profile := {
		"definition_path": definition.resource_path if definition and not definition.resource_path.is_empty() else "",
	}
	return profile


func _apply_profile_from_record(record: Dictionary) -> void:
	var profile_raw = record.get("profile", {})
	# Missing profile payload means scene-authored definition remains authoritative.
	if not profile_raw is Dictionary:
		# Keep authored definition behavior when no persisted profile payload exists.
		_apply_definition_to_children()
		return
	var profile := profile_raw as Dictionary
	var definition_path := str(profile.get("definition_path", ""))
	# Empty path means no persisted definition override is requested.
	if not definition_path.is_empty() and ResourceLoader.exists(definition_path):
		var loaded := load(definition_path)
		if loaded is Resource and loaded.get_script() == PERSON_DEFINITION_SCRIPT:
			# Persisted definition path can override scene-authored definition at runtime.
			definition = loaded
	_apply_definition_to_children()


func _apply_definition_to_children() -> void:
	# No definition means there is nothing to propagate to child components.
	if definition == null:
		return
	var collision_target_height := maxf(definition.height_meters, 0.1)
	var interactable := get_node_or_null("InteractablePerson") as InteractablePerson
	# Interactable child is optional in some utility/test scenes.
	if interactable:
		interactable.speaker_name = definition.speaker_name
		interactable.opening_text = definition.opening_text
		interactable.conversation = definition.conversation
		interactable.interact_label = "Talk to " + definition.speaker_name
	var sprite := get_node_or_null("Sprite3D") as Sprite3D
	# Sprite visuals are optional; collision still updates from default height.
	if sprite:
		sprite.texture = definition.portrait_texture
		sprite.scale = definition.sprite_scale
		var texture_height := sprite.texture.get_height() if sprite.texture else 0
		var scaled_height_factor: float = definition.sprite_scale.y if not is_zero_approx(definition.sprite_scale.y) else 1.0
		var world_height := 0.0
		if texture_height > 0 and definition.height_meters > 0.0:
			# final_world_height ~= pixel_size * texture_height * scale_y
			sprite.pixel_size = definition.height_meters / (float(texture_height) * scaled_height_factor)
			world_height = definition.height_meters
		elif texture_height > 0 and sprite.pixel_size > 0.0:
			# Reuse configured pixel size when explicit definition height is not set.
			world_height = sprite.pixel_size * float(texture_height) * scaled_height_factor
		if world_height > 0.0:
			# Keep feet fixed at the actor's ground origin while visual height changes.
			var sprite_position := sprite.position
			sprite_position.y = world_height * 0.5
			sprite.position = sprite_position
			collision_target_height = world_height
	_apply_collision_shape_from_height(collision_target_height)
	person_profile_changed.emit(self)


func _apply_collision_shape_from_height(target_height: float) -> void:
	# Collision update is skipped for invalid/non-positive target heights.
	if target_height <= 0.0:
		return
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	# Missing collision shape is tolerated for presentation-only actors.
	if collision == null:
		return
	# Capsule dimensions are derived from target visual height.
	if collision.shape is CapsuleShape3D:
		var capsule := collision.shape as CapsuleShape3D
		var target_radius := clampf(target_height * 0.16, 0.18, 0.45)
		capsule.radius = target_radius
		capsule.height = maxf(target_height - (target_radius * 2.0), target_radius * 0.5)
	var collision_position := collision.position
	collision_position.y = target_height * 0.5
	collision.position = collision_position
