extends CharacterBody3D

signal interactable_changed(interactable)

var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.005

# bob variables
const BOB_FREQUENCY = 2.0
const BOB_AMPLITUDE = 0.08
var t_bob = 0.0

# fov variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5


var gravity = 9.8
var _auto_walk := false
var _auto_walk_dir := Vector3.ZERO
var _auto_walk_remaining := 0.0
var _current_interactable: Interactable = null

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var _interact_ray: RayCast3D = $Head/Camera3D/InteractRay

func _unhandled_input(event):
	if _auto_walk:
		return
	if event.is_action_pressed("interact") and _current_interactable:
		var target := _current_interactable
		target.interact(self)
		_set_current_interactable(null)
		return
	if event is InputEventMouseMotion and not get_tree().paused:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-55), deg_to_rad(60))

func start_arrival_walk(direction: Vector3, distance: float) -> void:
	_auto_walk = true
	_auto_walk_dir = direction
	_auto_walk_remaining = distance


func _physics_process(delta: float) -> void:
	if _auto_walk:
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0.0
		velocity.x = _auto_walk_dir.x * WALK_SPEED
		velocity.z = _auto_walk_dir.z * WALK_SPEED
		_auto_walk_remaining -= WALK_SPEED * delta
		if _auto_walk_remaining <= 0.0:
			_auto_walk = false
		t_bob += delta * velocity.length() * float(is_on_floor())
		camera.transform.origin = _headbob(t_bob)
		camera.fov = lerp(camera.fov, BASE_FOV + FOV_CHANGE * clamp(velocity.length(), 0.5, SPRINT_SPEED * 2), delta * 8.0)
		move_and_slide()
		return
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction = (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 2.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 2.0)

	# head bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	
	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	move_and_slide()
	_check_interactable()


func _check_interactable() -> void:
	if _current_interactable != null and not is_instance_valid(_current_interactable):
		_set_current_interactable(null)
		return
	var found: Interactable = null
	if not _auto_walk and _interact_ray.is_colliding():
		var col := _interact_ray.get_collider()
		if col is Interactable and is_instance_valid(col):
			found = col as Interactable
	if found != _current_interactable:
		_set_current_interactable(found)


func _set_current_interactable(interactable: Interactable) -> void:
	if interactable == _current_interactable:
		return
	if is_instance_valid(_current_interactable):
		if _current_interactable.tree_exiting.is_connected(_on_current_interactable_exiting):
			_current_interactable.tree_exiting.disconnect(_on_current_interactable_exiting)
		_current_interactable._unhighlight()
	_current_interactable = interactable
	if _current_interactable:
		_current_interactable.tree_exiting.connect(_on_current_interactable_exiting, CONNECT_ONE_SHOT)
		_current_interactable._highlight()
	interactable_changed.emit(_current_interactable)


func _on_current_interactable_exiting() -> void:
	_current_interactable = null
	interactable_changed.emit(null)


func get_current_interactable() -> Interactable:
	if not is_instance_valid(_current_interactable):
		_current_interactable = null
	return _current_interactable
	
	
func _headbob(time) -> Vector3:
		var pos = Vector3.ZERO
		pos.y = sin(time * BOB_FREQUENCY) * BOB_AMPLITUDE
		pos.x = cos(time * BOB_FREQUENCY / 2) * BOB_AMPLITUDE
		return pos
