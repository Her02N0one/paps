## Movement intent scaffold for actor AI; pathfinding/steering implementation can replace this later.
class_name ActorMovementAIComponent
extends Node

signal target_changed(target: Node3D)
signal movement_intent_changed(desired_direction: Vector3)

@export var stopping_distance_meters := 1.6
@export var move_speed_meters_per_sec := 3.5

var _target: Node3D
var _desired_direction := Vector3.ZERO


func set_target(target: Node3D) -> void:
	_target = target
	target_changed.emit(_target)
	_update_desired_direction()


func clear_target() -> void:
	set_target(null)


func has_target() -> bool:
	return _target != null


func get_target() -> Node3D:
	return _target


func get_desired_direction() -> Vector3:
	return _desired_direction


func get_stopping_distance() -> float:
	return stopping_distance_meters


func set_move_speed(value: float) -> void:
	move_speed_meters_per_sec = maxf(value, 0.0)


func _process(_delta: float) -> void:
	_update_desired_direction()


func _update_desired_direction() -> void:
	if _target == null:
		if not _desired_direction.is_zero_approx():
			_desired_direction = Vector3.ZERO
			movement_intent_changed.emit(_desired_direction)
		return
	var actor_node := get_parent() as Node3D
	if actor_node == null:
		return
	var delta := _target.global_position - actor_node.global_position
	delta.y = 0.0
	var distance := delta.length()
	var next_direction := Vector3.ZERO
	if distance > stopping_distance_meters:
		next_direction = delta / distance
	if not _desired_direction.is_equal_approx(next_direction):
		_desired_direction = next_direction
		movement_intent_changed.emit(_desired_direction)
