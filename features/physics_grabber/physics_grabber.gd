class_name PhysicsGrabber
extends Marker3D

@export var camera: Camera3D

@export var grab_range := 3.0
@export var throw_impulse := 15.0
@export var grab_force := 15.0
@export var linear_damping := 5.0
@export var angular_damping := 5.0

var grabbed_body: RigidBody3D = null
var _original_linear_damp := 0.0
var _original_angular_damp := 0.0
var _interact_press_time := 0.0

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		_interact_press_time = Time.get_ticks_msec() / 1000.0
		
	if Input.is_action_pressed("interact"):
		var hold_duration = (Time.get_ticks_msec() / 1000.0) - _interact_press_time
		if hold_duration >= 0.2:
			if grabbed_body == null:
				_try_grab()
			else:
				_update_grab(delta)
	else:
		if grabbed_body != null:
			_drop()
			
	if grabbed_body != null and Input.is_action_just_pressed("throw"):
		_throw()

func _try_grab() -> void:
	var space = get_world_3d().direct_space_state
	var origin = camera.global_position
	var forward = -camera.global_transform.basis.z
	
	var query = PhysicsRayQueryParameters3D.create(origin, origin + forward * grab_range)
	query.collision_mask = 1 # Update mask if needed for physics props
	
	var result = space.intersect_ray(query)
	if result and result.collider is RigidBody3D:
		var body = result.collider as RigidBody3D
		if body.mass <= 50.0: # Arbitrary mass limit
			grabbed_body = body
			_original_linear_damp = body.linear_damp
			_original_angular_damp = body.angular_damp
			body.linear_damp = linear_damping
			body.angular_damp = angular_damping

func _update_grab(delta: float) -> void:
	if not is_instance_valid(grabbed_body):
		grabbed_body = null
		return
		
	var target_pos = global_position
	var current_pos = grabbed_body.global_position
	
	var dir = target_pos - current_pos
	var dist = dir.length()
	
	# Apply velocity to pull the body towards the anchor
	var force = dir.normalized() * (dist * grab_force)
	grabbed_body.linear_velocity = grabbed_body.linear_velocity.lerp(force, delta * 15.0)
	
	# Try to align its rotation with the player
	# Simple dampening keeps it from spinning wildly

func _drop() -> void:
	if is_instance_valid(grabbed_body):
		grabbed_body.linear_damp = _original_linear_damp
		grabbed_body.angular_damp = _original_angular_damp
	grabbed_body = null

func _throw() -> void:
	if is_instance_valid(grabbed_body):
		var body = grabbed_body
		_drop()
		var forward = -camera.global_transform.basis.z
		body.apply_central_impulse(forward * throw_impulse * body.mass)
