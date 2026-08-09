@tool
extends Area3D

@export var gateway_id: String = ""
@export_file("*.tscn") var target_scene: String = ""
@export var target_gateway_id: String = ""

var _line_mesh: ImmediateMesh
var _line_inst: MeshInstance3D


func _ready() -> void:
	_setup_line()
	if Engine.is_editor_hint():
		return
	add_to_group("gateways")
	body_entered.connect(_on_body_entered)
	_build_trigger_visual()


func _build_trigger_visual() -> void:
	var col := get_node_or_null("CollisionShape3D")
	if not col or not col.shape is BoxShape3D:
		return
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = (col.shape as BoxShape3D).size
	inst.mesh = mesh
	inst.position = col.position
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.35, 0.80)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	inst.material_override = mat
	add_child(inst)


func _setup_line() -> void:
	_line_inst = MeshInstance3D.new()
	_line_mesh = ImmediateMesh.new()
	_line_inst.mesh = _line_mesh
	_line_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.0)
	mat.flags_no_depth_test = true
	_line_inst.material_override = mat
	add_child(_line_inst)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or not _line_mesh:
		return
	var ws: Node3D = get_node_or_null("WalkStart")
	var we: Node3D = get_node_or_null("WalkEnd")
	_line_mesh.clear_surfaces()
	if not ws or not we:
		return
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_line_mesh.surface_add_vertex(to_local(ws.global_position))
	_line_mesh.surface_add_vertex(to_local(we.global_position))
	_line_mesh.surface_end()


func _on_body_entered(body: Node3D) -> void:
	var movement := _get_available_movement(body)
	if movement == null or movement.is_gateway_walking():
		return
	var reversed := _is_reverse_entry(movement)
	movement.request_gateway_travel(target_scene, target_gateway_id, reversed)


func _get_available_movement(body: Node3D) -> ActorMovementComponent:
	if not body is CharacterBody3D:
		return null
	return ActorMovementComponent.find_on(body)


func _is_reverse_entry(movement: ActorMovementComponent) -> bool:
	var walk_start: Node3D = get_node_or_null("WalkStart")
	if walk_start == null:
		return false
	var approach_direction := (global_position - walk_start.global_position).normalized()
	return movement.get_facing_direction().dot(approach_direction) < 0.0
