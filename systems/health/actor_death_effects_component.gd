## Optional death VFX router that subscribes to ActorHealthComponent.defeated and spawns configured effects.
## This component is intentionally opt-in and has no built-in default effect.
class_name ActorDeathEffectsComponent
extends Node

const DEATH_EFFECT_PROFILE_SCRIPT := preload("res://systems/health/actor_death_effect_profile.gd")

enum SelectionMode {
	FIRST_VALID,
	RANDOM_VALID,
	ALL_VALID,
}

signal death_effect_spawned(profile: ActorDeathEffectProfile, effect_instance: Node)

@export var health_component_path: NodePath = NodePath("../ActorHealthComponent")
@export var death_effect_profiles: Array[Resource] = []
@export var selection_mode: SelectionMode = SelectionMode.FIRST_VALID
@export var trigger_once := true

var _health_component: ActorHealthComponent
var _triggered := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_health_component = get_node_or_null(health_component_path) as ActorHealthComponent
	if _health_component == null:
		push_warning("ActorDeathEffectsComponent could not find ActorHealthComponent at '%s'." % String(health_component_path))
		return
	if not _health_component.defeated.is_connected(_on_health_defeated):
		_health_component.defeated.connect(_on_health_defeated)
	if not _health_component.revived.is_connected(_on_health_revived):
		_health_component.revived.connect(_on_health_revived)


func _exit_tree() -> void:
	if _health_component != null:
		if _health_component.defeated.is_connected(_on_health_defeated):
			_health_component.defeated.disconnect(_on_health_defeated)
		if _health_component.revived.is_connected(_on_health_revived):
			_health_component.revived.disconnect(_on_health_revived)


func _on_health_defeated(_source: Node) -> void:
	if trigger_once and _triggered:
		return
	var valid_profiles := _collect_valid_profiles()
	if valid_profiles.is_empty():
		return
	_triggered = true
	var selected := _select_profiles(valid_profiles)
	for profile in selected:
		_spawn_profile_effect(profile)
	_apply_owner_death_lifecycle(selected[0])


func _on_health_revived() -> void:
	if not trigger_once:
		_triggered = false


func _collect_valid_profiles() -> Array[ActorDeathEffectProfile]:
	var valid: Array[ActorDeathEffectProfile] = []
	for resource in death_effect_profiles:
		if resource == null:
			continue
		if resource.get_script() != DEATH_EFFECT_PROFILE_SCRIPT:
			continue
		var profile := resource as ActorDeathEffectProfile
		if profile.effect_scene == null:
			continue
		valid.append(profile)
	return valid


func _select_profiles(valid_profiles: Array[ActorDeathEffectProfile]) -> Array[ActorDeathEffectProfile]:
	if valid_profiles.is_empty():
		return []
	match selection_mode:
		SelectionMode.ALL_VALID:
			return valid_profiles
		SelectionMode.RANDOM_VALID:
			return [valid_profiles[randi() % valid_profiles.size()]]
		_:
			return [valid_profiles[0]]


func _spawn_profile_effect(profile: ActorDeathEffectProfile) -> void:
	var parent := _resolve_effect_parent(profile)
	if parent == null:
		return
	var instance := profile.effect_scene.instantiate()
	if instance == null:
		return
	parent.add_child(instance)
	_apply_effect_transform(instance, profile)
	death_effect_spawned.emit(profile, instance)
	if profile.effect_lifetime_seconds > 0.0:
		_schedule_queue_free(instance, profile.effect_lifetime_seconds)


func _resolve_effect_parent(profile: ActorDeathEffectProfile) -> Node:
	match profile.parent_mode:
		ActorDeathEffectProfile.ParentMode.OWNER_PARENT:
			return get_parent()
		ActorDeathEffectProfile.ParentMode.WORLD_EFFECT_ROOT:
			var world := get_tree().get_first_node_in_group("world")
			if world != null:
				var effect_root := world.get_node_or_null("GameplayWorld/EffectRoot")
				if effect_root != null:
					return effect_root
			return get_tree().current_scene
		_:
			return get_tree().current_scene


func _apply_effect_transform(instance: Node, profile: ActorDeathEffectProfile) -> void:
	var owner_node := get_parent() as Node3D
	if owner_node == null:
		return
	if instance is Node3D:
		var effect_node := instance as Node3D
		var spawn_origin := owner_node.global_transform.origin
		spawn_origin += owner_node.global_transform.basis * profile.spawn_offset_local
		if profile.inherit_owner_rotation:
			effect_node.global_transform = Transform3D(owner_node.global_transform.basis, spawn_origin)
		else:
			effect_node.global_transform = Transform3D(Basis.IDENTITY, spawn_origin)


func _apply_owner_death_lifecycle(profile: ActorDeathEffectProfile) -> void:
	var owner_node := get_parent()
	if owner_node == null:
		return
	if profile.hide_owner_visuals_on_trigger:
		_set_descendant_visibility(owner_node, false)
	if profile.queue_free_owner:
		if profile.queue_free_owner_delay_seconds <= 0.0:
			_retire_owner(owner_node)
		else:
			_schedule_retire_owner(owner_node, profile.queue_free_owner_delay_seconds)


func _set_descendant_visibility(node: Node, visible: bool) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).visible = visible
	for child in node.get_children():
		_set_descendant_visibility(child, visible)


func _schedule_queue_free(node: Node, delay_seconds: float) -> void:
	if node == null:
		return
	var timer := get_tree().create_timer(maxf(delay_seconds, 0.0))
	timer.timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free()
	)


## Persisted persons must be disabled (not just freed) so a dead NPC doesn't silently come back
## alive at full health on the next area load — set_person_enabled(false) already triggers its
## own queue_free() once the disabled state is persisted. Non-Person owners (e.g. the Player,
## which should never be auto-retired this way) fall back to a plain queue_free().
func _retire_owner(owner_node: Node) -> void:
	if owner_node.has_method("set_person_enabled"):
		owner_node.call("set_person_enabled", false)
	else:
		owner_node.queue_free()


func _schedule_retire_owner(node: Node, delay_seconds: float) -> void:
	if node == null:
		return
	var timer := get_tree().create_timer(maxf(delay_seconds, 0.0))
	timer.timeout.connect(func() -> void:
		if is_instance_valid(node):
			_retire_owner(node)
	)
