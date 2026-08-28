@tool
## Visual rendering component for grapple line presentation.
class_name GrappleVisualSystem
extends Node3D

@export var grapple_component: GrappleSystem
@export var movement_component: ActorMovementSystem

var _grapple_line: MeshInstance3D
var _grapple_mat: StandardMaterial3D


func _ready() -> void:
	if movement_component == null and get_parent() != null:
		movement_component = ActorMovementSystem.find_on(get_parent())
	# If grapple component isn't explicitly set, try to find it
	if grapple_component == null and get_parent() != null:
		for child in get_parent().get_children():
			if child is GrappleSystem:
				grapple_component = child as GrappleSystem
				break

	if Engine.is_editor_hint():
		return
	_setup_visuals()


func _setup_visuals() -> void:
	_grapple_line = MeshInstance3D.new()
	_grapple_mat = StandardMaterial3D.new()
	_grapple_mat.albedo_color = Color(1.0, 0.2, 0.2)
	_grapple_mat.emission_enabled = true
	_grapple_mat.emission = Color(1.0, 0.2, 0.2)
	_grapple_mat.emission_energy_multiplier = 4.0

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 1.0)
	_grapple_line.mesh = mesh
	_grapple_line.material_override = _grapple_mat
	_grapple_line.visible = false
	_grapple_line.top_level = true
	add_child(_grapple_line)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or grapple_component == null or movement_component == null:
		return

	if not grapple_component.is_grappling:
		if _grapple_line and _grapple_line.visible:
			_grapple_line.visible = false
		return

	if _grapple_line == null or _grapple_mat == null:
		return

	_grapple_line.visible = true
	var body := movement_component.body
	var facing_ref := movement_component.facing_reference
	var target := grapple_component.grapple_target
	var current_dist := body.global_position.distance_to(target) if body else 0.0
	var on_floor := body.is_on_floor() if body else false

	if on_floor:
		_grapple_mat.albedo_color = Color(0.5, 0.5, 0.5)
		_grapple_mat.emission = Color(0.5, 0.5, 0.5)
	else:
		_grapple_mat.albedo_color = Color(0.2, 0.8, 1.0)
		_grapple_mat.emission = Color(0.2, 0.8, 1.0)

	var start_pos := facing_ref.global_position if facing_ref else (body.global_position if body else global_position)
	start_pos.y -= 0.2
	_grapple_line.global_position = start_pos.lerp(target, 0.5)
	var up := Vector3.UP
	if absf(start_pos.direction_to(target).dot(Vector3.UP)) > 0.99:
		up = Vector3.RIGHT
	_grapple_line.look_at(target, up)
	_grapple_line.scale = Vector3(1.0, 1.0, start_pos.distance_to(target))
