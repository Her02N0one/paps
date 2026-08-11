## Generic attack capability: target assignment, cooldown gating, and damage payload emission.
class_name ActorCombatComponent
extends Node

signal target_changed(target: Node3D)
signal attack_attempted(target: Node3D)
signal attack_performed(target: Node3D, damage: float)
signal attack_blocked(reason: StringName)

const BLOCKED_NO_TARGET := &"no_target"
const BLOCKED_COOLDOWN := &"cooldown"
const BLOCKED_OUT_OF_RANGE := &"out_of_range"
const BLOCKED_SELF_DEFEATED := &"self_defeated"

@export var attack_range_meters := 2.0
@export var base_damage := 10.0
@export var attack_cooldown_seconds := 1.0

var _target: Node3D
var _cooldown_remaining := 0.0
var _health_component: Variant


func bind_health_component(component: Variant) -> void:
	_health_component = component


func physics_tick(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - maxf(delta, 0.0), 0.0)


func set_target(target: Node3D) -> void:
	_target = target
	target_changed.emit(_target)


func clear_target() -> void:
	set_target(null)


func get_target() -> Node3D:
	return _target


func can_attack(target: Node3D = _target) -> bool:
	if _health_component != null and not _health_component.is_alive():
		return false
	if target == null:
		return false
	if _cooldown_remaining > 0.0:
		return false
	var actor_node := get_parent() as Node3D
	if actor_node == null:
		return false
	return actor_node.global_position.distance_to(target.global_position) <= attack_range_meters


func try_attack(target: Node3D = _target) -> bool:
	attack_attempted.emit(target)
	if _health_component != null and not _health_component.is_alive():
		attack_blocked.emit(BLOCKED_SELF_DEFEATED)
		return false
	if target == null:
		attack_blocked.emit(BLOCKED_NO_TARGET)
		return false
	if _cooldown_remaining > 0.0:
		attack_blocked.emit(BLOCKED_COOLDOWN)
		return false
	if not can_attack(target):
		attack_blocked.emit(BLOCKED_OUT_OF_RANGE)
		return false
	_perform_attack(target)
	return true


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func _perform_attack(target: Node3D) -> void:
	_cooldown_remaining = maxf(attack_cooldown_seconds, 0.0)
	attack_performed.emit(target, base_damage)
	if target.has_method("apply_damage"):
		target.call("apply_damage", base_damage, get_parent())
