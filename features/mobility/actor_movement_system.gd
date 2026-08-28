@tool
## Movement state component for free movement and scripted gateway traversal.
class_name ActorMovementSystem
extends Node

signal gateway_requested(target_scene: String, target_gateway_id: String, reversed: bool)

@export var body: CharacterBody3D
@export var facing_reference: Node3D
@export var walk_speed := 4.3
@export var sprint_speed := 5.6
@export var jump_velocity := 8.5
@export var gravity := 32.0

@export var ground_friction := 7.0
@export var air_drag := 2.0
@export var air_control_speed := 3.0
@export var dash_power := 15.0
@export_group("Impulse Decay")
@export var ground_impulse_decay := 5.0
@export var air_impulse_decay := 0.2

# Vector Pools
var input_velocity := Vector3.ZERO
var impulse_velocity := Vector3.ZERO

# Inputs & State Flags
var direction := Vector3.ZERO
var sprint_requested := false
var jump_requested := false
var is_crouching := false
var friction_override := -1.0

var _gateway_walking := false
var _gateway_direction := Vector3.ZERO
var _gateway_distance_remaining := 0.0


func execute_dash(dash_direction: Vector3) -> void:
	# If the player is standing still, dash forward. Otherwise, dash in the direction they're moving.
	var dir = dash_direction if dash_direction != Vector3.ZERO else get_facing_direction()
	add_impulse(dir * dash_power)

func _ready() -> void:
	if body == null and get_parent() is CharacterBody3D:
		body = get_parent() as CharacterBody3D
	if Engine.is_editor_hint():
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null:
		warnings.append("ActorMovementSystem requires a CharacterBody3D 'body' reference or a CharacterBody3D parent.")
	return warnings


func physics_tick(delta: float) -> void:
	if body == null:
		return
		
	var pre_move_vel = body.velocity
		
	if _gateway_walking:
		_tick_gateway_walk(delta)
	else:
		_tick_free_movement(delta)
		
	body.move_and_slide()
	
	if not _gateway_walking:
		var post_move_vel = body.velocity
		if pre_move_vel != post_move_vel:
			# Lost velocity to an obstacle (wall/floor). Strip it from impulse_velocity to prevent desync.
			var post_h = Vector3(post_move_vel.x, 0, post_move_vel.z)
			if post_h.length_squared() > 0.001:
				var post_dir = post_h.normalized()
				if impulse_velocity.length_squared() > 0.001:
					var projected = post_dir * max(0.0, impulse_velocity.dot(post_dir))
					if projected.length_squared() < impulse_velocity.length_squared():
						impulse_velocity = projected
			else:
				impulse_velocity = Vector3.ZERO
	
	jump_requested = false


func start_gateway_walk(walk_direction: Vector3, distance: float) -> void:
	_gateway_walking = true
	_gateway_direction = walk_direction.normalized()
	_gateway_distance_remaining = maxf(distance, 0.0)
	input_velocity = Vector3.ZERO
	impulse_velocity = Vector3.ZERO


func place_at_gateway(walk_start: Node3D, walk_end: Node3D, _reversed: bool) -> void:
	if body == null or walk_start == null or walk_end == null:
		return
	var walk_direction := (walk_end.global_position - walk_start.global_position).normalized()
	body.global_position = walk_start.global_position
	body.rotation.y = atan2(-walk_direction.x, -walk_direction.z)
	reset_facing_reference()
	_sync_body_look_if_supported()
	start_gateway_walk(walk_direction, walk_start.global_position.distance_to(walk_end.global_position))


func place_at_spawn(spawn: Node3D) -> void:
	if body == null or spawn == null:
		return
	body.global_position = spawn.global_position
	body.rotation.y = spawn.rotation.y
	reset_facing_reference()
	_sync_body_look_if_supported()


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


static func find_on(actor: Node) -> ActorMovementSystem:
	var container = actor.get_node_or_null("Systems")
	var children = container.get_children() if container != null else actor.get_children()
	for child in children:
		if child is ActorMovementSystem:
			return child as ActorMovementSystem
	return null


# --- Gateway Movement ---

func _tick_gateway_walk(delta: float) -> void:
	if not body.is_on_floor():
		body.velocity.y -= gravity * delta
	else:
		body.velocity.y = 0.0
		
	body.velocity.x = _gateway_direction.x * walk_speed
	body.velocity.z = _gateway_direction.z * walk_speed
	
	_gateway_distance_remaining -= walk_speed * delta
	if _gateway_distance_remaining <= 0.0:
		_gateway_walking = false
		input_velocity = Vector3(_gateway_direction.x * walk_speed, 0, _gateway_direction.z * walk_speed)


func _tick_free_movement(delta: float) -> void:
	var on_floor = body.is_on_floor()
	var current_friction = air_drag
	
	if on_floor:
		current_friction = ground_friction
		
	if friction_override >= 0.0:
		current_friction = friction_override
		friction_override = -1.0 # Reset every tick
		
	# 1. Decay impulse velocity over time
	var impulse_decay = ground_impulse_decay if on_floor else air_impulse_decay
	if friction_override >= 0.0:
		impulse_decay = friction_override
	impulse_velocity.x = lerp(impulse_velocity.x, 0.0, delta * impulse_decay)
	impulse_velocity.z = lerp(impulse_velocity.z, 0.0, delta * impulse_decay)
	
	# 2. Process Input Velocity and Air-Strafing
	var target_speed = sprint_speed if sprint_requested else walk_speed
	
	if not on_floor and direction != Vector3.ZERO:
		var speed = impulse_velocity.length()
		if speed > target_speed * 1.5:
			# Steer impulse_velocity towards the input direction
			var current_dir = impulse_velocity.normalized()
			var steer_amount = air_control_speed * delta
			var new_dir = current_dir.slerp(direction, steer_amount).normalized()
			impulse_velocity = new_dir * speed
	if is_crouching:
		target_speed *= 0.5
		
	if direction != Vector3.ZERO:
		var accel = current_friction if on_floor else air_drag
		input_velocity.x = lerp(input_velocity.x, direction.x * target_speed, delta * accel)
		input_velocity.z = lerp(input_velocity.z, direction.z * target_speed, delta * accel)
	else:
		var decel = current_friction if on_floor else air_drag
		input_velocity.x = lerp(input_velocity.x, 0.0, delta * decel)
		input_velocity.z = lerp(input_velocity.z, 0.0, delta * decel)
		
	# 3. Vertical Velocity (Gravity and Jump)
	if not on_floor:
		body.velocity.y -= gravity * delta
	elif jump_requested:
		body.velocity.y = jump_velocity
		input_velocity = Vector3.ZERO

	# 5. Sum all vectors
	var combined_horizontal = input_velocity + impulse_velocity
	body.velocity.x = combined_horizontal.x
	body.velocity.z = combined_horizontal.z


func add_impulse(impulse: Vector3) -> void:
	impulse_velocity += impulse
	



func reset_facing_reference() -> void:
	if facing_reference != null and facing_reference != body:
		facing_reference.rotation.y = 0.0


func _sync_body_look_if_supported() -> void:
	if body.has_method("sync_look_to_body_yaw"):
		body.sync_look_to_body_yaw()
		body.sync_camera_to_body_anchor()
