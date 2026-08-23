@tool
## Travel trigger that computes entry direction and asks movement to request a map transfer.
class_name Gateway
extends Area3D

var gateway_id: String:
	get: return name

@export_file("*.tscn") var target_scene_path: String:
	set(value):
		target_scene_path = value
		notify_property_list_changed()

@export var target_gateway_id: String = ""

@export_group("Custom Walk Markers")
@export var custom_walk_start: Node3D
@export var custom_walk_end: Node3D

func _validate_property(property: Dictionary) -> void:
	if property.name == "target_gateway_id":
		var hint_string := ""
		if not target_scene_path.is_empty():
			var target_scene = load(target_scene_path) as PackedScene
			if target_scene != null:
				var state := target_scene.get_state()
				var ids := PackedStringArray()
				if state != null:
					for i in state.get_node_count():
						var n := state.get_node_name(i)
						if n.begins_with("Gateway"):
							ids.append(n)
				if not ids.is_empty():
					hint_string = ",".join(ids)
		
		if not hint_string.is_empty():
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = hint_string
		else:
			property.hint = PROPERTY_HINT_NONE
			property.hint_string = ""

var _line_mesh: ImmediateMesh
var _line_inst: MeshInstance3D


@onready var collision := $CollisionShape3D as CollisionShape3D

func _get_walk_start() -> Node3D:
	return custom_walk_start if is_instance_valid(custom_walk_start) else get_node_or_null("WalkStart")

func _get_walk_end() -> Node3D:
	return custom_walk_end if is_instance_valid(custom_walk_end) else get_node_or_null("WalkEnd")

func _ready() -> void:
	_setup_line()
	# Keep editor warnings up to date while authoring gateway nodes.
	if Engine.is_editor_hint():
		update_configuration_warnings()
	# Editor mode only needs gizmo visualization, not runtime trigger behavior.
	if Engine.is_editor_hint():
		# Editor only needs gizmo updates; runtime signal wiring is skipped.
		return
	add_to_group("gateways")
	body_entered.connect(_on_body_entered)
	_build_trigger_visual()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	# Empty target means trigger will fire without a destination scene.
	if target_scene_path.is_empty():
		warnings.append("Gateway target_scene_path is empty; travel requests will have no destination.")
	# Collision shape is required for body_entered signals.
	if get_node_or_null("CollisionShape3D") == null:
		warnings.append("Gateway requires a CollisionShape3D child to detect body entry.")
	# WalkStart/WalkEnd are optional at runtime but expected for smooth entry motion.
	if not is_instance_valid(_get_walk_start()) or not is_instance_valid(_get_walk_end()):
		warnings.append("Gateway should define WalkStart and WalkEnd Marker3D children (or assign custom ones) for scripted entry walking.")
	return warnings


func _build_trigger_visual() -> void:
	# Visual debug box only supports box collision shapes.
	if not collision or not collision.shape is BoxShape3D:
		return
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = (collision.shape as BoxShape3D).size
	inst.mesh = mesh
	inst.position = collision.position
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
	# Runtime mode skips editor-only lane preview rendering.
	if not Engine.is_editor_hint() or not _line_mesh:
		return
	var ws = _get_walk_start()
	var we = _get_walk_end()
	_line_mesh.clear_surfaces()
	if not is_instance_valid(ws) or not is_instance_valid(we):
		return
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_line_mesh.surface_add_vertex(to_local(ws.global_position))
	_line_mesh.surface_add_vertex(to_local(we.global_position))
	_line_mesh.surface_end()


func _on_body_entered(body: Node3D) -> void:
	var movement := _get_available_movement(body)
	# Ignore entries from non-player bodies and actors already in scripted gateway walk.
	if movement == null or movement.is_gateway_walking():
		return
	var reversed := _is_reverse_entry(movement)
	if target_scene_path.is_empty():
		return
	movement.request_gateway_travel(target_scene_path, target_gateway_id, reversed)


func _get_available_movement(body: Node3D) -> ActorMovementComponent:
	# Only character bodies are eligible for movement-based travel requests.
	if not body is CharacterBody3D:
		return null
	return ActorMovementComponent.find_on(body)


func _is_reverse_entry(movement: ActorMovementComponent) -> bool:
	var ws: Node3D = _get_walk_start()
	if not is_instance_valid(ws):
		return false
	var approach_direction: Vector3 = (global_position - ws.global_position).normalized()
	return movement.get_facing_direction().dot(approach_direction) < 0.0
