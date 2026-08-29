## Runtime player actor: routes input into movement, interaction probing, and camera feedback.
class_name Player
extends CharacterBody3D

signal interactable_changed(interactable)
signal gateway_travel_requested(target_scene: String, gateway_id: String, reversed: bool)

@export_group("Body Profile")
@export var hide_body_in_first_person := true

@export var head: Node3D
@export var camera_anchor: Marker3D
@export var camera: Camera3D
@export var movement: ActorMovementSystem
@export var grapple: GrappleSystem
@export var camera_system: PlayerCameraSystem
@export var interaction_sensor: InteractionSensor
@export var inventory_holder: InventoryHolderComponent
@export var equipment_holder: EquipmentHolder
@export var health_component: ActorHealthComponent
@export var collision_shape: CollisionShape3D

var _interact_press_time := 0.0


func _ready() -> void:
	_apply_first_person_body_visibility()
	sync_look_to_body_yaw()
	movement.gateway_requested.connect(_on_gateway_requested)
	interaction_sensor.interactable_changed.connect(interactable_changed.emit)


func _apply_first_person_body_visibility() -> void:
	var body_mesh := get_node("%WorldModel/MeshInstance3D") as MeshInstance3D
	body_mesh.visible = not hide_body_in_first_person
	health_component.health_changed.connect(func(c, m): MessageBus.player_health_changed.emit(c, m))
	health_component.damaged.connect(func(a, s): MessageBus.player_damaged.emit(a, s))

func get_standing_height() -> float:
	return (collision_shape.shape as CapsuleShape3D).height


func get_eye_level() -> float:
	return camera_anchor.position.y

func _process(delta: float) -> void:
	camera_system.process_tick(delta)


func bind_inventory(inventory: InventoryStore) -> void:
	inventory_holder.configure(inventory)


func _unhandled_input(event):
	# While gateway walking is active, manual control is suppressed to avoid desync.
	if movement.is_gateway_walking():
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	# Interaction consumes the input when activation succeeds.
	if event.is_action_pressed("interact"):
		_interact_press_time = Time.get_ticks_msec() / 1000.0
		return
		
	if event.is_action_released("interact"):
		var hold_duration = (Time.get_ticks_msec() / 1000.0) - _interact_press_time
		if hold_duration < 0.2:
			interaction_sensor.activate(self)
		return
		
	if event.is_action_pressed("fire_weapon"):
		equipment_holder.fire()
	elif event.is_action_released("fire_weapon"):
		equipment_holder.release_fire()
			
	if event is InputEventMouseMotion:
		camera_system.apply_camera_look(event.relative)
		
	if event.is_action_pressed("jump"):
		movement.jump_requested = true
		
	if event.is_action_pressed("dash"):
		movement.execute_dash(movement.direction)
		
	if event.is_action_pressed("grapple"):
		grapple.start_grapple(camera.global_position, -camera.global_transform.basis.z)

func _physics_process(delta: float) -> void:
	_update_movement_requests()
	movement.physics_tick(delta)
	_update_interaction_sensor()
	camera_system.physics_tick(delta, self)


func _update_movement_requests() -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		movement.direction = Vector3.ZERO
		movement.sprint_requested = false
		movement.jump_requested = false
		movement.is_crouching = false
		return
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	# Movement follows target yaw immediately while render view can smooth independently.
	var yaw_basis := Basis(Vector3.UP, camera_system._target_yaw)
	movement.direction = (yaw_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var sprint_pressed = Input.is_action_pressed("sprint")
	var crouch_pressed = Input.is_action_pressed("crouch")
	
	movement.sprint_requested = sprint_pressed and not crouch_pressed
	movement.is_crouching = crouch_pressed


func _update_interaction_sensor() -> void:
	# Interaction raycasts are disabled during scripted gateway movement.
	interaction_sensor.enabled = not movement.is_gateway_walking()
	interaction_sensor.physics_tick()


func get_current_interactable() -> Interactable:
	return interaction_sensor.get_current_interactable()


func apply_damage(amount: float, source: Node = null) -> float:
	return health_component.apply_damage(amount, source)


func _on_gateway_requested(target_scene: String, target_gateway_id: String, reversed: bool) -> void:
	gateway_travel_requested.emit(target_scene, target_gateway_id, reversed)


func sync_look_to_body_yaw() -> void:
	camera_system.sync_look_to_yaw(rotation.y)

func sync_camera_to_body_anchor() -> void:
	camera_system.sync_camera_to_body_anchor()
