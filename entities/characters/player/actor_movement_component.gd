@tool
## Movement state component for free movement and scripted gateway traversal.
class_name ActorMovementComponent
extends Node

signal gateway_requested(target_scene: String, target_gateway_id: String, reversed: bool)

@export var body: CharacterBody3D
@export var facing_reference: Node3D
@export var walk_speed := 4.3
@export var sprint_speed := 5.6
@export var jump_velocity := 8.5
@export var gravity := 32.0

@export var ground_friction := 7.0
@export var slide_friction := 1.0
@export var air_drag := 2.0
@export var dash_impulse := 15.0
@export var slide_impulse := 8.0

# Vector Pools
var input_velocity := Vector3.ZERO
var impulse_velocity := Vector3.ZERO
var grapple_velocity := Vector3.ZERO

# Inputs & State Flags
var direction := Vector3.ZERO
var sprint_requested := false
var jump_requested := false
var is_crouching := false
var is_sliding := false
var is_grappling := false
var grapple_boost_requested := false

var _gateway_walking := false
var _gateway_direction := Vector3.ZERO
var _gateway_distance_remaining := 0.0

var _grapple_line: MeshInstance3D

func _ready() -> void:
	if body == null and get_parent() is CharacterBody3D:
		body = get_parent() as CharacterBody3D
	if Engine.is_editor_hint():
		update_configuration_warnings()
	else:
		_setup_grapple_visual()

func _setup_grapple_visual() -> void:
	_grapple_line = MeshInstance3D.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2)
	mat.emission_energy_multiplier = 4.0
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 1.0)
	_grapple_line.mesh = mesh
	_grapple_line.material_override = mat
	_grapple_line.visible = false
	_grapple_line.top_level = true
	add_child.call_deferred(_grapple_line)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null:
		warnings.append("ActorMovementComponent requires a CharacterBody3D 'body' reference or a CharacterBody3D parent.")
	return warnings


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
	input_velocity = Vector3.ZERO
	impulse_velocity = Vector3.ZERO
	grapple_velocity = Vector3.ZERO


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


static func find_on(actor: Node) -> ActorMovementComponent:
	if actor == null:
		return null
	for child in actor.get_children():
		if child is ActorMovementComponent:
			return child as ActorMovementComponent
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


@export var grapple_range := 30.0
@export var grapple_speed := 30.0
@export var grapple_min_length := 2.0
@export var grapple_spring_strength := 10.0

var _grapple_target := Vector3.ZERO

func start_grapple(origin: Vector3, dir: Vector3) -> void:
	if is_grappling:
		# Toggle off
		is_grappling = false
		grapple_velocity = Vector3.ZERO
		if _grapple_line:
			_grapple_line.visible = false
		return
		
	var space = body.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, origin + dir * grapple_range)
	query.exclude = [body.get_rid()]
	var result = space.intersect_ray(query)
	
	if result:
		_grapple_target = result.position
		is_grappling = true
		body.velocity.y += 4.0 # Give a little hop off the ground

func _tick_free_movement(delta: float) -> void:
	var on_floor = body.is_on_floor()
	var current_friction = air_drag
	
	if on_floor:
		current_friction = slide_friction if is_sliding else ground_friction
		
	# 1. Decay impulse velocity over time
	impulse_velocity.x = lerp(impulse_velocity.x, 0.0, delta * current_friction)
	impulse_velocity.z = lerp(impulse_velocity.z, 0.0, delta * current_friction)
	
	# 2. Process Input Velocity
	var target_speed = sprint_speed if sprint_requested else walk_speed
	if is_crouching and not is_sliding:
		target_speed *= 0.5
		
	if is_sliding:
		# During a slide, input cannot accelerate you forward, but we still allow minor air-strafing like steering
		input_velocity.x = lerp(input_velocity.x, direction.x * (target_speed * 0.2), delta * current_friction)
		input_velocity.z = lerp(input_velocity.z, direction.z * (target_speed * 0.2), delta * current_friction)
	elif direction != Vector3.ZERO:
		var accel = current_friction if on_floor else air_drag
		input_velocity.x = lerp(input_velocity.x, direction.x * target_speed, delta * accel)
		input_velocity.z = lerp(input_velocity.z, direction.z * target_speed, delta * accel)
	else:
		# Decelerate
		var decel = current_friction if on_floor else air_drag
		input_velocity.x = lerp(input_velocity.x, 0.0, delta * decel)
		input_velocity.z = lerp(input_velocity.z, 0.0, delta * decel)
		
	# 3. Process Grapple
	if is_grappling:
		if jump_requested:
			is_grappling = false
			if _grapple_line:
				_grapple_line.visible = false
		else:
			var pull_dir = (_grapple_target - body.global_position).normalized()
			var distance = body.global_position.distance_to(_grapple_target)
			
			if distance > grapple_min_length:
				# Base reel-in is very low, you mainly swing. Holding F boosts it to winch you up.
				var reel_speed = 5.0
				if grapple_boost_requested:
					reel_speed = 60.0
					
				var reel_force = pull_dir * reel_speed
				impulse_velocity += Vector3(reel_force.x, 0, reel_force.z) * delta
				body.velocity.y += reel_force.y * delta
				
				# Perfect Pendulum Constraint
				# Calculate total intended velocity for this frame (including upcoming gravity)
				var current_vel = Vector3(input_velocity.x + impulse_velocity.x, body.velocity.y, input_velocity.z + impulse_velocity.z)
				if not on_floor:
					current_vel.y -= gravity * delta
					
				var outward_speed = -current_vel.dot(pull_dir)
				if outward_speed > 0:
					# Apply exact counter-force to negate any velocity moving AWAY from the anchor
					var correction = pull_dir * outward_speed
					impulse_velocity += Vector3(correction.x, 0, correction.z)
					body.velocity.y += correction.y
				
			if _grapple_line:
				_grapple_line.visible = true
				var start_pos = facing_reference.global_position if facing_reference else body.global_position
				start_pos.y -= 0.2
				_grapple_line.global_position = start_pos.lerp(_grapple_target, 0.5)
				var up = Vector3.UP
				if abs(start_pos.direction_to(_grapple_target).dot(Vector3.UP)) > 0.99:
					up = Vector3.RIGHT
				_grapple_line.look_at(_grapple_target, up)
				_grapple_line.scale = Vector3(1.0, 1.0, start_pos.distance_to(_grapple_target))
	elif _grapple_line and _grapple_line.visible:
		_grapple_line.visible = false
	
	# 4. Vertical Velocity (Gravity and Jump)
	if not on_floor:
		body.velocity.y -= gravity * delta
	elif jump_requested:
		body.velocity.y = jump_velocity
		is_sliding = false # Jumping breaks a slide
		# Preserve slide momentum by converting input to impulse
		impulse_velocity += input_velocity
		input_velocity = Vector3.ZERO

	# 5. Sum all vectors
	var combined_horizontal = input_velocity + impulse_velocity
	body.velocity.x = combined_horizontal.x
	body.velocity.z = combined_horizontal.z


func add_impulse(impulse: Vector3) -> void:
	impulse_velocity += impulse
	
func enter_slide() -> void:
	if not is_sliding and body.is_on_floor():
		is_sliding = true
		# Convert current forward momentum into an impulse, plus a little boost
		var facing = get_facing_direction()
		var slide_dir = facing
		if direction != Vector3.ZERO:
			slide_dir = direction
			
		impulse_velocity += slide_dir * slide_impulse
		input_velocity = Vector3.ZERO


func dash(dash_dir: Vector3 = Vector3.ZERO) -> void:
	if dash_dir == Vector3.ZERO:
		dash_dir = get_facing_direction()
	impulse_velocity += dash_dir * dash_impulse


func reset_facing_reference() -> void:
	if facing_reference != null and facing_reference != body:
		facing_reference.rotation.y = 0.0


func _sync_body_look_if_supported() -> void:
	var player = body
	if player and player.has_method("sync_look_to_body_yaw"):
		player.sync_look_to_body_yaw()
		player.sync_camera_to_body_anchor()
