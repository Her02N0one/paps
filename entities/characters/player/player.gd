## Runtime player actor: routes input into movement, interaction probing, and camera feedback.
class_name Player
extends CharacterBody3D

signal interactable_changed(interactable)
signal gateway_travel_requested(target_scene: String, gateway_id: String, reversed: bool)

const SENSITIVITY = 0.005

const BOB_FREQUENCY = 2.0
const BOB_AMPLITUDE = 0.08
var t_bob = 0.0

const BASE_FOV = 70.0
const FOV_CHANGE = 1.5
const MIN_PITCH := deg_to_rad(-90.0)
const MAX_PITCH := deg_to_rad(90.0)

const HEIGHT_TO_RADIUS_RATIO = 0.18
const MIN_CAPSULE_RADIUS = 0.22
const MAX_CAPSULE_RADIUS = 0.45

@export_group("Body Profile")
@export_range(1.2, 2.4, 0.01) var standing_height_meters := 1.8
@export_range(0.5, 0.98, 0.01) var eye_height_ratio := 0.9
@export var auto_fit_capsule_collision := true
@export var auto_fit_body_mesh := true
@export var hide_body_in_first_person := true
@export_range(0.0, 60.0, 0.1) var look_smoothing_speed := 24.0


@onready var head: Node3D = $Head
@onready var camera_anchor: Marker3D = $CameraAnchor
@onready var camera: Camera3D = $Head/Camera3D
@onready var movement: ActorMovementComponent = $ActorMovementComponent
@onready var interaction_sensor: InteractionSensorComponent = $InteractionSensorComponent
@onready var inventory_holder: InventoryHolderComponent = $InventoryHolderComponent
@onready var health_component: ActorHealthComponent = $ActorHealthComponent

var _target_yaw := 0.0
var _target_pitch := 0.0
var _visual_yaw := 0.0
var _visual_pitch := 0.0


func _ready() -> void:
	_apply_first_person_body_visibility()
	refresh_body_profile()
	sync_look_to_body_yaw()
	# Camera look smoothing runs in _process, so disable physics interpolation to avoid warning spam.
	if camera != null:
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_sync_camera_rig_transform(true)
	movement.gateway_requested.connect(_on_gateway_requested)
	interaction_sensor.interactable_changed.connect(interactable_changed.emit)


func _apply_first_person_body_visibility() -> void:
	var body_mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if body_mesh == null:
		return
	body_mesh.visible = not hide_body_in_first_person


func refresh_body_profile() -> void:
	_sync_physical_profile()


func _sync_physical_profile() -> void:
	# Keep camera eye line and capsule dimensions derived from one canonical standing height.
	standing_height_meters = maxf(standing_height_meters, 1.2)
	if auto_fit_capsule_collision:
		var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision and collision.shape is CapsuleShape3D:
			collision.shape = (collision.shape as CapsuleShape3D).duplicate()
			var capsule := collision.shape as CapsuleShape3D
			var target_radius := clampf(standing_height_meters * HEIGHT_TO_RADIUS_RATIO, MIN_CAPSULE_RADIUS, MAX_CAPSULE_RADIUS)
			capsule.radius = target_radius
			capsule.height = maxf(standing_height_meters, target_radius * 2.0)
			var collision_position: Vector3 = collision.position
			collision_position.y = standing_height_meters * 0.5
			collision.position = collision_position
	if auto_fit_body_mesh:
		var body_mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
		if body_mesh:
			if body_mesh.mesh is CapsuleMesh:
				body_mesh.mesh = (body_mesh.mesh as CapsuleMesh).duplicate()
				var capsule_mesh := body_mesh.mesh as CapsuleMesh
				var mesh_radius := clampf(standing_height_meters * HEIGHT_TO_RADIUS_RATIO, MIN_CAPSULE_RADIUS, MAX_CAPSULE_RADIUS)
				capsule_mesh.radius = mesh_radius
				capsule_mesh.height = maxf(standing_height_meters, mesh_radius * 2.0)
			var mesh_position: Vector3 = body_mesh.position
			mesh_position.y = standing_height_meters * 0.5
			body_mesh.position = mesh_position
	if head:
		var anchor_position: Vector3 = camera_anchor.position
		anchor_position.y = standing_height_meters * eye_height_ratio
		camera_anchor.position = anchor_position
		_sync_camera_rig_transform(true)


func _process(delta: float) -> void:
	_apply_interpolated_look(delta)


func bind_inventory(inventory: InventoryStore) -> void:
	inventory_holder.configure(inventory)


func _unhandled_input(event):
	# While gateway walking is active, manual control is suppressed to avoid desync.
	if movement.is_gateway_walking():
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	# Interaction consumes the input when activation succeeds.
	if event.is_action_pressed("interact") and interaction_sensor.activate(self):
		return
	if event is InputEventMouseMotion:
		_apply_camera_look(event)


func _physics_process(delta: float) -> void:
	_sync_camera_rig_transform(true)
	_update_movement_requests()
	movement.physics_tick(delta)
	_update_interaction_sensor()
	_update_camera_effects(delta)


func _update_movement_requests() -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		movement.direction = Vector3.ZERO
		movement.sprint_requested = false
		movement.jump_requested = false
		return
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	# Movement follows target yaw immediately while render view can smooth independently.
	var yaw_basis := Basis(Vector3.UP, _target_yaw)
	movement.direction = (yaw_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	movement.sprint_requested = Input.is_action_pressed("sprint")
	movement.jump_requested = Input.is_action_just_pressed("jump")


func _update_interaction_sensor() -> void:
	# Interaction raycasts are disabled during scripted gateway movement.
	interaction_sensor.enabled = not movement.is_gateway_walking()
	interaction_sensor.physics_tick()


func _apply_camera_look(event: InputEventMouseMotion) -> void:
	_target_yaw -= event.relative.x * SENSITIVITY
	_target_pitch = clamp(_target_pitch - event.relative.y * SENSITIVITY, MIN_PITCH, MAX_PITCH)


func _update_camera_effects(delta: float) -> void:
	# Bobbing scales with speed and only while grounded for less noisy airborne camera motion.
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	# FOV response is intentionally clamped to keep sprint readable without fisheye extremes.
	var sprint_cap = movement.sprint_speed * 2 if movement else 16.0
	var velocity_clamped = clamp(velocity.length(), 0.5, sprint_cap)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)


func get_current_interactable() -> Interactable:
	return interaction_sensor.get_current_interactable()


func apply_damage(amount: float, source: Node = null) -> float:
	if health_component == null:
		return 0.0
	return health_component.apply_damage(amount, source)


func _on_gateway_requested(target_scene: String, target_gateway_id: String, reversed: bool) -> void:
	gateway_travel_requested.emit(target_scene, target_gateway_id, reversed)


func _sync_camera_rig_transform(force_current_transform: bool) -> void:
	if head == null or camera_anchor == null:
		return
	var anchor_transform = camera_anchor.global_transform if force_current_transform else camera_anchor.get_global_transform_interpolated()
	# Preserve current yaw/pitch while sampling interpolated anchor translation.
	head.global_position = anchor_transform.origin


func _apply_interpolated_look(delta: float) -> void:
	if head == null or camera == null:
		return
	if look_smoothing_speed <= 0.0:
		_visual_yaw = _target_yaw
		_visual_pitch = _target_pitch
	else:
		var alpha := clampf(delta * look_smoothing_speed, 0.0, 1.0)
		_visual_yaw = lerp_angle(_visual_yaw, _target_yaw, alpha)
		_visual_pitch = lerpf(_visual_pitch, _target_pitch, alpha)
	head.rotation.y = _visual_yaw
	camera.rotation.x = _visual_pitch


func sync_look_to_body_yaw() -> void:
	_target_yaw = rotation.y
	_target_pitch = 0.0
	_visual_yaw = _target_yaw
	_visual_pitch = _target_pitch
	if head != null:
		head.rotation.y = _visual_yaw
	if camera != null:
		camera.rotation.x = _visual_pitch


func sync_camera_to_body_anchor() -> void:
	_sync_camera_rig_transform(true)
	
	
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQUENCY) * BOB_AMPLITUDE
	pos.x = cos(time * BOB_FREQUENCY / 2) * BOB_AMPLITUDE
	return pos
