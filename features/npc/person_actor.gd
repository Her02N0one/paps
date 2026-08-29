@tool
## Persisted NPC actor. Composes identity/persistence, visual presentation, and behavior components.
class_name PersonActor
extends CharacterBody3D

const PERSON_VISUAL_RIG_COMPONENT_SCRIPT := preload("res://features/npc/person_visual_rig.gd")
const PERSON_PERSISTENCE_COMPONENT_SCRIPT := preload("res://features/npc/person_persistence_system.gd")


signal person_profile_changed(actor: PersonActor)
signal person_transform_changed(actor: PersonActor)

@export var person_id: StringName
@export var persist_transform := true

var _definition: PersonDefinition
@export var definition: PersonDefinition:
	get:
		return _definition
	set(value):
		_disconnect_definition_changed(_definition)
		_definition = value
		_connect_definition_changed(_definition)
		_reset_attachment_reference_cache()
		if Engine.is_editor_hint():
			if is_node_ready():
				_apply_definition_to_children()


@onready var interactable_person_component: InteractablePerson = get_node_or_null("InteractablePerson") as InteractablePerson
@onready var movement_component: ActorMovementSystem = get_node_or_null("ActorMovementSystem") as ActorMovementSystem
@onready var health_component: ActorHealthComponent = get_node_or_null("ActorHealthComponent") as ActorHealthComponent
@onready var visual_rig_component: PersonVisualRig = get_node_or_null("PersonVisualRig") as PersonVisualRig
@onready var persistence_component: PersonPersistenceSystem = get_node_or_null("PersonPersistenceSystem") as PersonPersistenceSystem

var _warned_non_unit_scale := false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	return warnings


func _connect_definition_changed(resource: Resource) -> void:
	if resource == null:
		return
	if not resource.changed.is_connected(_on_definition_changed):
		resource.changed.connect(_on_definition_changed)


func _disconnect_definition_changed(resource: Resource) -> void:
	if resource == null:
		return
	if resource.changed.is_connected(_on_definition_changed):
		resource.changed.disconnect(_on_definition_changed)


func _on_definition_changed() -> void:
	_apply_definition_to_children()


func _ready() -> void:
	if visual_rig_component == null:
		push_error("PersonActor '%s' is missing a PersonVisualRig." % name)
	if persistence_component == null:
		push_error("PersonActor '%s' is missing a PersonPersistenceSystem." % name)
	_connect_definition_changed(_definition)
	_normalize_body_scale_if_needed()
	_reset_attachment_reference_cache()
	if Engine.is_editor_hint():
		update_configuration_warnings()
		_apply_definition_to_children()
		set_process(true)
		return
	_wire_phase_one_components()
	if not persistence_component.register_and_restore(self):
		queue_free()
		return

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if visual_rig_component != null:
		visual_rig_component.update_billboard_attachment_facing()
	if movement_component != null:
		movement_component.physics_tick(delta)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_normalize_body_scale_if_needed()


func _exit_tree() -> void:
	_disconnect_definition_changed(_definition)
	if persistence_component != null:
		persistence_component.release_persistence(self)


# Persistence Delegation

func has_game_state() -> bool:
	return persistence_component != null and persistence_component._game_state != null


func get_person_id() -> StringName:
	return persistence_component.get_person_id(self) if persistence_component else StringName()


func set_person_area(target_area_path: String, target_transform: Transform3D = global_transform) -> void:
	if persistence_component != null:
		persistence_component.set_person_area(self, target_area_path, target_transform)


func set_person_enabled(enabled: bool) -> void:
	if persistence_component != null:
		persistence_component.set_person_enabled(self, enabled)


func is_person_enabled() -> bool:
	return persistence_component.is_person_enabled() if persistence_component else true


func set_person_state_value(key: StringName, value: Variant) -> void:
	if persistence_component != null:
		persistence_component.set_person_state_value(key, value)


func get_person_state_value(key: StringName, default_value: Variant = null) -> Variant:
	return persistence_component.get_person_state_value(key, default_value) if persistence_component else default_value


func set_person_flag(flag: StringName, value: bool) -> void:
	if persistence_component != null:
		persistence_component.set_person_flag(flag, value)


func get_person_flag(flag: StringName, default_value: bool = false) -> bool:
	return persistence_component.get_person_flag(flag, default_value) if persistence_component else default_value


func apply_profile(profile: Dictionary) -> void:
	if persistence_component != null:
		persistence_component.apply_profile(self, profile)


# Public API

func has_person_definition() -> bool:
	return definition != null


func get_person_definition() -> PersonDefinition:
	return definition


func refresh_person_profile() -> void:
	_apply_definition_to_children()
	person_profile_changed.emit(self)


func apply_damage(amount: float, source: Node = null) -> float:
	if health_component != null:
		return health_component.apply_damage(amount, source)
	return 0.0


func set_person_speaker_name(value: String) -> void:
	if definition != null:
		definition.speaker_name = value
		refresh_person_profile()


func set_person_conversation(value: DialogueConversation) -> void:
	if definition != null:
		definition.conversation = value
		refresh_person_profile()


func set_person_body_texture(value: Texture2D) -> void:
	if definition != null:
		definition.body_texture = value
		refresh_person_profile()


func set_person_height_meters(value: float) -> void:
	if definition != null:
		definition.height_meters = maxf(value, 0.01)
		refresh_person_profile()


func set_person_sprite_scale(value: Vector3) -> void:
	if definition != null:
		definition.sprite_scale = value
		refresh_person_profile()


func get_person_visual_height_meters() -> float:
	var sprite := get_node_or_null("Sprite3D") as Sprite3D
	if sprite == null or sprite.texture == null:
		return 0.0
	return sprite.pixel_size * float(sprite.texture.get_height()) * sprite.scale.y


func teleport_person_to(position_world: Vector3) -> void:
	global_position = position_world
	if persistence_component != null:
		persistence_component.persist_current_transform_if_active(self)
	person_transform_changed.emit(self)


func teleport_person_transform(transform_world: Transform3D) -> void:
	global_transform = transform_world
	if persistence_component != null:
		persistence_component.persist_current_transform_if_active(self)
	person_transform_changed.emit(self)


func face_person_towards(target_world: Vector3) -> void:
	if global_position.is_equal_approx(target_world):
		return
	look_at(target_world, Vector3.UP, true)
	if persistence_component != null:
		persistence_component.persist_current_transform_if_active(self)
	person_transform_changed.emit(self)


func _wire_phase_one_components() -> void:
	if Engine.is_editor_hint():
		return
	if health_component != null and definition != null:
		health_component.set_max_health(definition.max_health, true)


func _apply_definition_to_children() -> void:
	if definition == null:
		return
	if visual_rig_component != null:
		visual_rig_component.apply_person_definition(definition)
	_apply_definition_to_interactable(definition)
	if health_component != null:
		health_component.apply_person_definition(definition)
	person_profile_changed.emit(self)


func _apply_definition_to_interactable(person_definition: PersonDefinition) -> void:
	if interactable_person_component == null:
		return
	interactable_person_component.person_definition = person_definition


func _reset_attachment_reference_cache() -> void:
	if visual_rig_component != null:
		visual_rig_component.reset_attachment_reference_cache()


func _normalize_body_scale_if_needed() -> void:
	if scale.is_equal_approx(Vector3.ONE):
		return
	scale = Vector3.ONE
	if not _warned_non_unit_scale:
		push_warning("PersonActor root scale was reset to (1,1,1). Use PersonDefinition.height_meters and node transforms instead of scaling CharacterBody3D.")
		_warned_non_unit_scale = true
