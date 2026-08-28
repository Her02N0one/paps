class_name PlayerCameraSystem
extends Node

const SENSITIVITY := 0.005
const BOB_FREQUENCY := 2.0
const BOB_AMPLITUDE := 0.08
const BASE_FOV := 70.0
const FOV_CHANGE := 1.5
const MIN_PITCH := deg_to_rad(-90.0)
const MAX_PITCH := deg_to_rad(90.0)

@export var head: Node3D
@export var camera: Camera3D
@export var camera_anchor: Marker3D
@export var movement: ActorMovementSystem

@export_range(0.0, 60.0, 0.1) var look_smoothing_speed := 24.0

var _target_yaw := 0.0
var _target_pitch := 0.0
var _visual_yaw := 0.0
var _visual_pitch := 0.0
var _t_bob := 0.0

func _ready() -> void:
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

func apply_camera_look(relative: Vector2) -> void:
	_target_yaw -= relative.x * SENSITIVITY
	_target_pitch = clampf(_target_pitch - relative.y * SENSITIVITY, MIN_PITCH, MAX_PITCH)

func get_target_yaw() -> float:
	return _target_yaw

func sync_look_to_yaw(yaw: float) -> void:
	_target_yaw = yaw
	_target_pitch = 0.0
	_visual_yaw = yaw
	_visual_pitch = 0.0
	head.rotation.y = _visual_yaw
	camera.rotation.x = _visual_pitch

func sync_camera_to_body_anchor() -> void:
	_sync_camera_rig_transform()

func process_tick(delta: float) -> void:
	_apply_interpolated_look(delta)

func physics_tick(delta: float, body: CharacterBody3D) -> void:
	_sync_camera_rig_transform()
	_update_camera_effects(delta, body)

func _sync_camera_rig_transform() -> void:
	var anchor_transform := camera_anchor.global_transform
	# Preserve current yaw/pitch while sampling interpolated anchor translation.
	head.global_position = anchor_transform.origin

func _apply_interpolated_look(delta: float) -> void:
	if look_smoothing_speed <= 0.0:
		_visual_yaw = _target_yaw
		_visual_pitch = _target_pitch
	else:
		var alpha := clampf(delta * look_smoothing_speed, 0.0, 1.0)
		_visual_yaw = lerp_angle(_visual_yaw, _target_yaw, alpha)
		_visual_pitch = lerpf(_visual_pitch, _target_pitch, alpha)
	head.rotation.y = _visual_yaw
	camera.rotation.x = _visual_pitch

func _update_camera_effects(delta: float, body: CharacterBody3D) -> void:
	
	var vel_length := body.velocity.length()
	var grounded := body.is_on_floor()
	
	# Bobbing
	_t_bob += delta * vel_length * float(grounded)
	var pos := Vector3.ZERO
	pos.y = sin(_t_bob * BOB_FREQUENCY) * BOB_AMPLITUDE
	pos.x = cos(_t_bob * BOB_FREQUENCY / 2) * BOB_AMPLITUDE
	camera.transform.origin = pos
	
	# FOV response
	var sprint_cap := movement.sprint_speed * 2.0
	var velocity_clamped := clampf(vel_length, 0.5, sprint_cap)
	var target_fov := BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerpf(camera.fov, target_fov, delta * 8.0)
