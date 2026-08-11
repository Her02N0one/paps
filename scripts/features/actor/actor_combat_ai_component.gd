## Lightweight combat AI state scaffold; later milestones can swap this for richer planners/BTs.
class_name ActorCombatAIComponent
extends Node

enum CombatState {
	IDLE,
	PURSUE,
	ATTACK,
	DISENGAGE,
}

signal combat_state_changed(previous_state: CombatState, next_state: CombatState)

@export var engage_distance_meters := 8.0
@export var disengage_distance_meters := 12.0

var _state: CombatState = CombatState.IDLE
var _target: Node3D
var _combat_component: Variant
var _health_component: Variant


func bind_components(combat_component: Variant, health_component: Variant) -> void:
	_combat_component = combat_component
	_health_component = health_component


func set_target(target: Node3D) -> void:
	_target = target
	if _combat_component != null:
		_combat_component.set_target(target)


func clear_target() -> void:
	set_target(null)


func get_target() -> Node3D:
	return _target


func get_state() -> CombatState:
	return _state


func physics_tick(_delta: float) -> void:
	var next_state := _resolve_next_state()
	if next_state != _state:
		var previous := _state
		_state = next_state
		combat_state_changed.emit(previous, _state)
	if _state == CombatState.ATTACK and _combat_component != null:
		_combat_component.try_attack(_target)


func _resolve_next_state() -> CombatState:
	if _health_component != null and not _health_component.is_alive():
		return CombatState.DISENGAGE
	if _target == null:
		return CombatState.IDLE
	var actor_node := get_parent() as Node3D
	if actor_node == null:
		return CombatState.IDLE
	var distance := actor_node.global_position.distance_to(_target.global_position)
	if distance <= engage_distance_meters and _combat_component != null and _combat_component.can_attack(_target):
		return CombatState.ATTACK
	if distance <= disengage_distance_meters:
		return CombatState.PURSUE
	return CombatState.DISENGAGE
