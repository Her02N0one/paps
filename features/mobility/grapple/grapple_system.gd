@tool
class_name GrappleSystem extends Node

@export var movement_component: ActorMovementSystem

@export_group("Grapple Behaviors")
@export var min_distance: float = 3.0
@export var mid_distance: float = 10.0
@export var max_distance: float = 20.0
@export var base_pull_multiplier: float = 2.3
@export var mid_pull_multiplier: float = 0.7
@export var rubberband_multiplier: float = 2.0

@export_group("Range & Speed")
@export var max_range: float = 30.0

var is_grappling := false
var grapple_target := Vector3.ZERO

func _ready() -> void:
	if movement_component == null and get_parent() is ActorMovementSystem:
		movement_component = get_parent() as ActorMovementSystem
	if Engine.is_editor_hint():
		update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if movement_component == null:
		warnings.append("GrappleSystem requires a movement_component reference.")
	return warnings

func start_grapple(origin: Vector3, dir: Vector3) -> void:
	if is_grappling:
		# Toggle off
		is_grappling = false
		return
		
	if movement_component == null or movement_component.body == null:
		return
		
	var space = movement_component.body.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, origin + dir * max_range)
	query.exclude = [movement_component.body.get_rid()]
	var result = space.intersect_ray(query)
	
	if result:
		grapple_target = result.position
		is_grappling = true

func _physics_process(delta: float) -> void:
	if not is_grappling or movement_component == null:
		return

	var body = movement_component.body
	if body == null:
		return
		
	var cancel_grapple := false
	if movement_component.jump_requested:
		if not body.is_on_floor():
			cancel_grapple = true
			
	if cancel_grapple:
		is_grappling = false
		return
		
	var pull_dir: Vector3 = (grapple_target - body.global_position).normalized()
	var current_distance: float = body.global_position.distance_to(grapple_target)
	
	if current_distance <= min_distance:
		is_grappling = false
		return
		
	var gravity_accel: float = movement_component.gravity * delta
	var pull_force := pull_dir * gravity_accel * base_pull_multiplier
	
	if current_distance > min_distance and current_distance < mid_distance:
		pass # Use full force
	elif current_distance >= mid_distance and current_distance < max_distance:
		pull_force *= mid_pull_multiplier # Scale down a bit at a distance
	else:
		pull_force *= rubberband_multiplier # Massive rubberband pull when exceeding max distance
		
	if pull_force != Vector3.ZERO:
		movement_component.add_impulse(Vector3(pull_force.x, 0.0, pull_force.z))
		body.velocity.y += pull_force.y
