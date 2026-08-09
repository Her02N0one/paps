class_name ActorMovementComponent
extends Node

signal gateway_requested(target_scene: String, target_gateway_id: String, reversed: bool)

@export var body: CharacterBody3D
@export var facing_reference: Node3D
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
@export var gravity := 9.8

var direction := Vector3.ZERO
var sprint_requested := false
var jump_requested := false

var _gateway_walking := false
var _gateway_direction := Vector3.ZERO
var _gateway_distance_remaining := 0.0


func physics_tick(delta: float) -> void:
	if body == null:
		return
	if _gateway_walking:
		_tick_gateway_walk(delta)
	else:
		_tick_free_movement(delta)
	body.move_and_slide()
	jump_requested = false


func start_gateway_walk(walk_direction: Vector3, distance: float) -> void:
	_gateway_walking = true
	_gateway_direction = walk_direction.normalized()
	_gateway_distance_remaining = maxf(distance, 0.0)


func place_at_gateway(walk_start: Node3D, walk_end: Node3D, reversed: bool) -> void:
	if body == null or walk_start == null or walk_end == null:
		return
	var walk_direction := (walk_end.global_position - walk_start.global_position).normalized()
	body.global_position = walk_start.global_position
	body.rotation.y = atan2(walk_direction.x, walk_direction.z) if reversed else atan2(-walk_direction.x, -walk_direction.z)
	_reset_facing_reference()
	start_gateway_walk(walk_direction, walk_start.global_position.distance_to(walk_end.global_position))


func place_at_spawn(spawn: Node3D) -> void:
	if body == null or spawn == null:
		return
	body.global_position = spawn.global_position
	body.rotation.y = spawn.rotation.y
	_reset_facing_reference()


func request_gateway_travel(target_scene: String, target_gateway_id: String, reversed: bool) -> void:
	gateway_requested.emit(target_scene, target_gateway_id, reversed)


func is_gateway_walking() -> bool:
	return _gateway_walking


func get_facing_direction() -> Vector3:
	var reference := facing_reference if facing_reference != null else body
	if reference == null:
		return Vector3.ZERO
	var forward := -reference.global_transform.basis.z
	return Vector3(forward.x, 0.0, forward.z).normalized()


static func find_on(actor: Node) -> ActorMovementComponent:
	if actor == null:
		return null
	for child in actor.get_children():
		if child is ActorMovementComponent:
			return child as ActorMovementComponent
	return null


func _tick_gateway_walk(delta: float) -> void:
	_apply_gateway_vertical_velocity(delta)
	_apply_gateway_horizontal_velocity()
	_advance_gateway_walk(delta)


func _apply_gateway_vertical_velocity(delta: float) -> void:
	if not body.is_on_floor():
		body.velocity.y -= gravity * delta
	else:
		body.velocity.y = 0.0


func _apply_gateway_horizontal_velocity() -> void:
	body.velocity.x = _gateway_direction.x * walk_speed
	body.velocity.z = _gateway_direction.z * walk_speed


func _advance_gateway_walk(delta: float) -> void:
	_gateway_distance_remaining -= walk_speed * delta
	if _gateway_distance_remaining <= 0.0:
		_gateway_walking = false


func _tick_free_movement(delta: float) -> void:
	_apply_free_movement_vertical_velocity(delta)
	_apply_free_movement_horizontal_velocity(delta)


func _apply_free_movement_vertical_velocity(delta: float) -> void:
	if not body.is_on_floor():
		body.velocity.y -= gravity * delta
	if jump_requested and body.is_on_floor():
		body.velocity.y = jump_velocity


func _apply_free_movement_horizontal_velocity(delta: float) -> void:
	var speed := sprint_speed if sprint_requested else walk_speed
	if body.is_on_floor():
		_apply_ground_velocity(speed, delta)
	else:
		_apply_air_velocity(speed, delta)


func _apply_ground_velocity(speed: float, delta: float) -> void:
	if direction:
		body.velocity.x = direction.x * speed
		body.velocity.z = direction.z * speed
	else:
		body.velocity.x = lerp(body.velocity.x, 0.0, delta * 7.0)
		body.velocity.z = lerp(body.velocity.z, 0.0, delta * 7.0)


func _apply_air_velocity(speed: float, delta: float) -> void:
	body.velocity.x = lerp(body.velocity.x, direction.x * speed, delta * 2.0)
	body.velocity.z = lerp(body.velocity.z, direction.z * speed, delta * 2.0)


func _reset_facing_reference() -> void:
	if facing_reference != null and facing_reference != body:
		facing_reference.rotation.y = 0.0
