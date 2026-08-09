extends CharacterBody3D

signal interactable_changed(interactable)

const SPRINT_SPEED = 8.0
const SENSITIVITY = 0.005

const BOB_FREQUENCY = 2.0
const BOB_AMPLITUDE = 0.08
var t_bob = 0.0

const BASE_FOV = 75.0
const FOV_CHANGE = 1.5


@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var movement: ActorMovementComponent = $ActorMovementComponent
@onready var interaction_sensor: InteractionSensorComponent = $InteractionSensorComponent
@onready var inventory_holder: InventoryHolderComponent = $InventoryHolderComponent


func _ready() -> void:
	inventory_holder.configure(Inventory)
	movement.gateway_requested.connect(_on_gateway_requested)
	interaction_sensor.interactable_changed.connect(interactable_changed.emit)


func _unhandled_input(event):
	if movement.is_gateway_walking():
		return
	if event.is_action_pressed("interact") and interaction_sensor.activate(self):
		return
	if event is InputEventMouseMotion and not get_tree().paused:
		_apply_camera_look(event)


func _physics_process(delta: float) -> void:
	_update_movement_requests()
	movement.physics_tick(delta)
	_update_interaction_sensor()
	_update_camera_effects(delta)


func _update_movement_requests() -> void:
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	movement.direction = (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	movement.sprint_requested = Input.is_action_pressed("sprint")
	movement.jump_requested = Input.is_action_just_pressed("jump")


func _update_interaction_sensor() -> void:
	interaction_sensor.enabled = not movement.is_gateway_walking()
	interaction_sensor.physics_tick()


func _apply_camera_look(event: InputEventMouseMotion) -> void:
	head.rotate_y(-event.relative.x * SENSITIVITY)
	camera.rotate_x(-event.relative.y * SENSITIVITY)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-55), deg_to_rad(60))


func _update_camera_effects(delta: float) -> void:
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)


func get_current_interactable() -> Interactable:
	return interaction_sensor.get_current_interactable()


func _on_gateway_requested(target_scene: String, target_gateway_id: String, reversed: bool) -> void:
	GameManager.travel(target_scene, target_gateway_id, reversed)
	
	
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQUENCY) * BOB_AMPLITUDE
	pos.x = cos(time * BOB_FREQUENCY / 2) * BOB_AMPLITUDE
	return pos
