## Structured movement gym generator with distinct training zones.
## Zones are intentionally spaced apart to keep readability high while tuning movement values.
@tool
class_name GymMetrics
extends Node3D

const _GREEN := Color(0.2, 0.82, 0.24, 0.85)
const _ORANGE := Color(0.95, 0.62, 0.18, 0.85)
const _RED := Color(0.84, 0.22, 0.2, 0.88)
const _PURPLE := Color(0.58, 0.34, 0.82, 0.9)
const _CYAN := Color(0.2, 0.8, 1.0, 0.8)
const _GRAY := Color(0.62, 0.65, 0.68, 0.82)
const _WHITE := Color(0.95, 0.95, 0.95, 1.0)
const _RANGE_COLOR := Color(0.16, 0.48, 0.6, 0.78)
const _SLOPE_COLOR := Color(0.3, 0.55, 0.35, 0.82)
const _STEP_COLOR := Color(0.28, 0.38, 0.56, 0.85)

const _DEFAULT_JUMP_ZONE_CENTER := Vector3(0.0, 0.0, -18.0)
const _DEFAULT_SLOPE_ZONE_CENTER := Vector3(18.0, 0.0, -6.0)
const _DEFAULT_STEP_ZONE_CENTER := Vector3(-18.0, 0.0, -8.0)
const _DEFAULT_RANGE_ZONE_CENTER := Vector3(0.0, 0.0, 18.0)
const _DEFAULT_REF_ZONE_CENTER := Vector3(-8.0, 0.0, -22.0)
const _DEFAULT_BOARD_POSITION := Vector3(-11.0, 1.7, -11.0)

@export_group("Movement (match ActorMovementSystem)")
@export var walk_speed: float = 4.8:
	set(v):
		walk_speed = v
		_schedule_rebuild()
@export var sprint_speed: float = 7.2:
	set(v):
		sprint_speed = v
		_schedule_rebuild()
@export var jump_velocity: float = 4.1:
	set(v):
		jump_velocity = v
		_schedule_rebuild()
@export var gravity: float = 10.8:
	set(v):
		gravity = v
		_schedule_rebuild()

@export_group("Layout")
@export var use_anchor_nodes_for_layout := false:
	set(v):
		use_anchor_nodes_for_layout = v
		_schedule_rebuild()
@export var instruction_board_position := _DEFAULT_BOARD_POSITION:
	set(v):
		instruction_board_position = v
		_schedule_rebuild()
@export var jump_zone_center := _DEFAULT_JUMP_ZONE_CENTER:
	set(v):
		jump_zone_center = v
		_schedule_rebuild()
@export var slope_zone_center := _DEFAULT_SLOPE_ZONE_CENTER:
	set(v):
		slope_zone_center = v
		_schedule_rebuild()
@export var step_zone_center := _DEFAULT_STEP_ZONE_CENTER:
	set(v):
		step_zone_center = v
		_schedule_rebuild()
@export var range_zone_center := _DEFAULT_RANGE_ZONE_CENTER:
	set(v):
		range_zone_center = v
		_schedule_rebuild()
@export var reference_zone_center := _DEFAULT_REF_ZONE_CENTER:
	set(v):
		reference_zone_center = v
		_schedule_rebuild()
@export_range(3.0, 9.0, 0.1) var jump_set_spacing := 4.6:
	set(v):
		jump_set_spacing = v
		_schedule_rebuild()

@export_group("Layout Anchors (optional Node3D paths)")
@export_node_path("Node3D") var instruction_board_anchor_path: NodePath:
	set(v):
		instruction_board_anchor_path = v
		_schedule_rebuild()
@export_node_path("Node3D") var jump_zone_anchor_path: NodePath:
	set(v):
		jump_zone_anchor_path = v
		_schedule_rebuild()
@export_node_path("Node3D") var slope_zone_anchor_path: NodePath:
	set(v):
		slope_zone_anchor_path = v
		_schedule_rebuild()
@export_node_path("Node3D") var step_zone_anchor_path: NodePath:
	set(v):
		step_zone_anchor_path = v
		_schedule_rebuild()
@export_node_path("Node3D") var range_zone_anchor_path: NodePath:
	set(v):
		range_zone_anchor_path = v
		_schedule_rebuild()
@export_node_path("Node3D") var reference_zone_anchor_path: NodePath:
	set(v):
		reference_zone_anchor_path = v
		_schedule_rebuild()

@export_group("Other")
@export var interaction_range: float = 4.0:
	set(v):
		interaction_range = v
		_schedule_rebuild()
@export var player_height: float = 1.69:
	set(v):
		player_height = v
		_schedule_rebuild()
@export_group("Persistence")
@export var save_generated_nodes_in_scene := false:
	set(v):
		save_generated_nodes_in_scene = v
		_schedule_rebuild()
@export var rebuild_when_scene_runs := true
@warning_ignore("unused_private_class_variable")
@export_tool_button("Rebuild Metrics") var _rebuild_btn: Callable = _rebuild
var _spawn_parent: Node = self
var _generated_root: Node3D = null
var _meter_texture_cache: Dictionary = {}


func _ready() -> void:
	if rebuild_when_scene_runs:
		_rebuild()


func _schedule_rebuild() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		call_deferred("_rebuild")


func _rebuild() -> void:
	_clear_generated_children()
	_meter_texture_cache.clear()
	_generated_root = _create_generated_root()
	_spawn_parent = _generated_root

	var air_time := 2.0 * jump_velocity / gravity
	var jump_height := (jump_velocity * jump_velocity) / (2.0 * gravity)
	var walk_range := walk_speed * air_time
	var sprint_range := sprint_speed * air_time

	_instruction_board(jump_height, walk_range, sprint_range)
	_reference_zone(jump_height)
	_jump_blocks_zone(walk_range, sprint_range)
	_slope_zone()
	_step_zone()
	_range_zone(interaction_range)

	print("[GymMetrics] walk=%.2f sprint=%.2f jump_height=%.2f walk_range=%.2f sprint_range=%.2f" % [
		walk_speed,
		sprint_speed,
		jump_height,
		walk_range,
		sprint_range,
	])


func _instruction_board(jump_height: float, walk_range: float, sprint_range: float) -> void:
	var board_position := _get_layout_point(instruction_board_position, instruction_board_anchor_path)
	var previous_parent := _spawn_parent
	_spawn_parent = _create_zone_root("Zone_Instruction", board_position)
	var board_group := _create_group_node("Board")
	var previous_board_parent := _spawn_parent
	_spawn_parent = board_group

	var board := MeshInstance3D.new()
	board.name = "InstructionBoard"
	board.position = Vector3.ZERO
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(0.1, 2.3, 4.0)
	board.mesh = board_mesh
	board.material_override = _mat(Color(0.08, 0.1, 0.14, 0.94))
	_own(add_child_ex(board))
	_label(board, "Movement Gym", Vector3(0.2, 0.92, -1.35), "Title")

	var body_text := "Walk %.1f m/s\nSprint %.1f m/s\nJump apex %.2f m\nWalk jump %.1f m\nSprint jump %.1f m\n\nZones:\n- Discrete jump sets\n- Slope lane (continuous)\n- Step-up lane\n- Interaction range"
	_label(board, body_text % [walk_speed, sprint_speed, jump_height, walk_range, sprint_range], Vector3(0.2, 0.2, 0.0), "Stats")

	_spawn_parent = previous_board_parent

	_spawn_parent = previous_parent


func _reference_zone(jump_height: float) -> void:
	var ref_center := _get_layout_point(reference_zone_center, reference_zone_anchor_path)
	var previous_parent := _spawn_parent
	_spawn_parent = _create_zone_root("Zone_Reference", ref_center)

	var labels_group := _create_group_node("Labels")
	var previous_labels_parent := _spawn_parent
	_spawn_parent = labels_group
	_floor_label(Vector3(0.0, 0.01, -1.6), "Reference", "ZoneLabel")
	_spawn_parent = previous_labels_parent

	var marker_parent := _create_group_node("Markers")
	var previous_marker_parent := _spawn_parent
	_spawn_parent = marker_parent
	_marker_box(Vector3(-1.8, player_height * 0.5, 0.0), Vector3(0.6, player_height, 0.3), _GRAY, "Player\n%.2f m" % player_height, "PlayerHeight")
	_marker_box(Vector3(1.0, jump_height * 0.5, 0.0), Vector3(0.4, jump_height, 0.4), _CYAN, "Jump apex\n%.2f m" % jump_height, "JumpApex")
	_spawn_parent = previous_marker_parent

	_spawn_parent = previous_parent


func _jump_blocks_zone(walk_range: float, sprint_range: float) -> void:
	var jump_center := _get_layout_point(jump_zone_center, jump_zone_anchor_path)
	var previous_parent := _spawn_parent
	_spawn_parent = _create_zone_root("Zone_JumpSets", jump_center)

	var labels_group := _create_group_node("Labels")
	var previous_labels_parent := _spawn_parent
	_spawn_parent = labels_group
	_floor_label(Vector3(0.0, 0.01, 3.2), "Discrete jump sets", "ZoneLabel")
	_spawn_parent = previous_labels_parent

	var sets_parent := _create_group_node("Sets")
	var previous_sets_parent := _spawn_parent
	_spawn_parent = sets_parent

	var start_size := Vector3(2.6, 0.5, 2.2)
	var landing_size := Vector3(2.6, 0.5, 2.2)
	var start_z := 2.2

	var set_gaps: Array[float] = [
		walk_range * 0.4,
		walk_range * 0.65,
		walk_range * 0.88,
		sprint_range * 0.62,
		sprint_range * 0.82,
		sprint_range * 0.98,
		sprint_range * 1.12,
	]
	var set_labels := PackedStringArray([
		"Walk easy",
		"Walk medium",
		"Walk max",
		"Sprint easy",
		"Sprint medium",
		"Sprint max",
		"Overshoot",
	])
	var set_modes := PackedStringArray([
		"walk",
		"walk",
		"walk",
		"sprint",
		"sprint",
		"sprint",
		"any",
	])
	var set_colors: Array[Color] = [
		_GREEN,
		Color(0.42, 0.84, 0.24, 0.88),
		_ORANGE,
		Color(0.95, 0.5, 0.2, 0.88),
		_RED,
		Color(0.78, 0.2, 0.2, 0.9),
		_PURPLE,
	]
	var set_x_offsets := _centered_offsets(set_gaps.size(), jump_set_spacing)

	for i in range(set_gaps.size()):
		var prior_parent := _spawn_parent
		var jump_set_name := "Set_%02d_%s_%ddm" % [i + 1, _name_token(set_labels[i]), int(round(set_gaps[i] * 10.0))]
		var set_start := Vector3(set_x_offsets[i], 0.0, start_z)
		_spawn_parent = _create_group_node(jump_set_name, set_start)
		_place_discrete_jump_set(Vector3.ZERO, start_size, landing_size, set_gaps[i], set_colors[i], set_labels[i], set_modes[i], i + 1)
		_spawn_parent = prior_parent

	_spawn_parent = previous_sets_parent

	_spawn_parent = previous_parent


func _place_discrete_jump_set(start_pos: Vector3, start_size: Vector3, landing_size: Vector3, gap: float, color: Color, label: String, movement_mode: String, set_index: int) -> void:
	_platform_with_meter_texture(start_pos, start_size, _GRAY, "Start", "StartPlatform")

	var start_front_z := start_pos.z - start_size.z * 0.5
	var landing_center_z := start_front_z - gap - landing_size.z * 0.5
	var landing_pos := Vector3(start_pos.x, 0.0, landing_center_z)
	var landing_label := "%s\n%.1f m (%s)" % [label, gap, movement_mode]
	_platform_with_meter_texture(landing_pos, landing_size, color, landing_label, "LandingPlatform")

	_floor_label(Vector3(start_pos.x, 0.01, start_pos.z + start_size.z * 0.5 + 0.45), "Set %d - %.1f m" % [set_index, gap], "GapLabel")


func _slope_zone() -> void:
	var slope_center := _get_layout_point(slope_zone_center, slope_zone_anchor_path)
	var previous_parent := _spawn_parent
	_spawn_parent = _create_zone_root("Zone_Slopes", slope_center)

	var labels_group := _create_group_node("Labels")
	var previous_labels_parent := _spawn_parent
	_spawn_parent = labels_group
	_floor_label(Vector3(0.0, 0.01, -6.5), "Slope lane", "ZoneLabel")
	_spawn_parent = previous_labels_parent

	var lanes_parent := _create_group_node("Lanes")
	var previous_lanes_parent := _spawn_parent
	_spawn_parent = lanes_parent
	_build_continuous_slope_lane(Vector3(-2.6, 0.0, -6.0), 7.0, 9.0, _SLOPE_COLOR, "gentle")
	_build_continuous_slope_lane(Vector3(2.6, 0.0, -5.5), 6.0, 14.0, _STEP_COLOR, "steep")
	_spawn_parent = previous_lanes_parent

	_spawn_parent = previous_parent


func _step_zone() -> void:
	var step_center := _get_layout_point(step_zone_center, step_zone_anchor_path)
	var previous_parent := _spawn_parent
	_spawn_parent = _create_zone_root("Zone_Steps", step_center)

	var labels_group := _create_group_node("Labels")
	var previous_labels_parent := _spawn_parent
	_spawn_parent = labels_group
	_floor_label(Vector3(0.0, 0.01, -5.0), "Step-up lane", "ZoneLabel")
	_spawn_parent = previous_labels_parent

	var step_series := _create_group_node("StepSeries")
	var previous_step_series := _spawn_parent
	_spawn_parent = step_series

	# Curb progression with small gaps between blocks to test stepping behavior.
	var widths := [2.6, 2.6, 2.6, 2.6, 2.6]
	var heights := [0.12, 0.18, 0.24, 0.3, 0.36]
	var z_cursor := -2.0
	for index in range(widths.size()):
		var previous_step_parent := _spawn_parent
		var height := float(heights[index])
		var length := 1.6
		_spawn_parent = _create_group_node("Step_%02d_%dcm" % [index + 1, int(round(height * 100.0))])
		var size := Vector3(float(widths[index]), height, length)
		var center_z := z_cursor
		_platform(Vector3(0.0, 0.0, center_z), size, _STEP_COLOR, "", "StepPlatform")
		_floor_label(Vector3(2.3, 0.01, center_z), "%.2f m" % height, "StepHeight")
		z_cursor += length + 0.35
		_spawn_parent = previous_step_parent

	# Short raised traversal lane for repeated step tests.
	_platform(Vector3(0.0, 0.0, 8.0), Vector3(4.2, 0.24, 3.0), _STEP_COLOR, "raised lane", "RaisedLane")
	_spawn_parent = previous_step_series

	_spawn_parent = previous_parent


func _range_zone(radius: float) -> void:
	var range_center := _get_layout_point(range_zone_center, range_zone_anchor_path)
	var previous_parent := _spawn_parent
	_spawn_parent = _create_zone_root("Zone_Range", range_center)

	var labels_group := _create_group_node("Labels")
	var previous_labels_parent := _spawn_parent
	_spawn_parent = labels_group
	_floor_label(Vector3(0.0, 0.01, -radius - 1.6), "Interaction range", "ZoneLabel")
	_floor_label(Vector3(radius + 1.0, 0.01, 0.0), "%.1f m" % radius, "RadiusLabel")
	_spawn_parent = previous_labels_parent

	_interaction_ring(Vector3.ZERO, radius, "InteractionRing")

	_spawn_parent = previous_parent


func _build_continuous_slope_lane(lane_start: Vector3, ramp_length: float, angle_degrees: float, color: Color, label_prefix: String) -> void:
	var previous_parent := _spawn_parent
	_spawn_parent = _create_group_node("Lane_%s" % _name_token(label_prefix), lane_start)

	var lane_width := 2.8
	var ramp_thickness := 0.16
	var crest_thickness := 0.18
	var crest_length := 3.4
	var seam_overlap := 1.15
	var entry_surface_y := 0.04

	var angle_rad := deg_to_rad(angle_degrees)
	var rise := sin(angle_rad) * ramp_length
	var half_ramp_top := ramp_thickness * 0.5 * cos(angle_rad)
	var up_center := Vector3(0.0, entry_surface_y - half_ramp_top + rise * 0.5, ramp_length * 0.5)
	var crest_surface_y := entry_surface_y + rise
	var crest_base_y := crest_surface_y - crest_thickness - 0.04

	_ramp(up_center, Vector3(lane_width, ramp_thickness, ramp_length), -angle_degrees, color, "%s up" % label_prefix, "RampUp")

	var crest_center_z := ramp_length + crest_length * 0.5 - seam_overlap
	_platform(Vector3(0.0, crest_base_y, crest_center_z), Vector3(lane_width, crest_thickness, crest_length), color, "walk-through", "Crest")

	var down_start_z := ramp_length + crest_length - seam_overlap * 2.0
	var down_center := Vector3(
		0.0,
		crest_surface_y - half_ramp_top - rise * 0.5,
		down_start_z + ramp_length * 0.5
	)
	_ramp(down_center, Vector3(lane_width, ramp_thickness, ramp_length), angle_degrees, color, "%s down" % label_prefix, "RampDown")

	_spawn_parent = previous_parent


func _create_zone_root(zone_name: String, zone_position: Vector3 = Vector3.ZERO) -> Node3D:
	var zone_root := Node3D.new()
	zone_root.name = zone_name
	zone_root.position = zone_position
	_own(add_child_ex(zone_root))
	return zone_root


func _create_group_node(group_name: String, group_position: Vector3 = Vector3.ZERO) -> Node3D:
	var group := Node3D.new()
	group.name = group_name
	group.position = group_position
	_own(add_child_ex(group))
	return group


func _create_generated_root() -> Node3D:
	var root := Node3D.new()
	root.name = "GeneratedGymMetrics"
	root.position = Vector3.ZERO
	add_child(root)
	_own(root)
	return root


func _name_token(raw_text: String) -> String:
	var token := raw_text.to_lower().replace(" ", "_").replace("-", "_")
	return token


func _get_layout_point(fallback_point: Vector3, anchor_path: NodePath) -> Vector3:
	if use_anchor_nodes_for_layout:
		return _resolve_anchor_local_or_fallback(anchor_path, fallback_point)
	return fallback_point


func _resolve_anchor_local_or_fallback(anchor_path: NodePath, fallback_point: Vector3) -> Vector3:
	if anchor_path.is_empty():
		return fallback_point
	var node3d: Node3D = get_node_or_null(anchor_path) as Node3D
	if node3d == null:
		return fallback_point
	return to_local(node3d.global_position)


func _centered_offsets(count: int, spacing: float) -> Array[float]:
	var values: Array[float] = []
	if count <= 0:
		return values
	var start := -0.5 * spacing * float(count - 1)
	for index in range(count):
		values.append(start + float(index) * spacing)
	return values


func _platform_with_meter_texture(pos: Vector3, size: Vector3, color: Color, label_text: String, node_name: String = "Platform") -> void:
	var body := _platform_base(pos, size, node_name)
	var mi := body.get_node("Mesh") as MeshInstance3D
	mi.material_override = _meter_material(color, size.x, size.z)
	if not label_text.is_empty():
		_label(body, label_text, Vector3(0.0, size.y * 0.55 + 0.18, 0.0), "Label")


func _platform(pos: Vector3, size: Vector3, color: Color, label_text: String, node_name: String = "Platform") -> void:
	var body := _platform_base(pos, size, node_name)
	var mi := body.get_node("Mesh") as MeshInstance3D
	mi.material_override = _mat(color)
	if not label_text.is_empty():
		_label(body, label_text, Vector3(0.0, size.y * 0.55 + 0.18, 0.0), "Label")


func _platform_base(pos: Vector3, size: Vector3, node_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos + Vector3(0.0, size.y * 0.5, 0.0)

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	body.add_child(mi)
	_own(mi)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	_own(col)

	_own(add_child_ex(body))
	return body


func _ramp(center: Vector3, size: Vector3, angle_degrees: float, color: Color, label_text: String = "", node_name: String = "Ramp") -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.rotation_degrees.x = angle_degrees

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _mat(color)
	body.add_child(mi)
	_own(mi)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	_own(col)

	_own(add_child_ex(body))
	if not label_text.is_empty():
		_label(body, label_text, Vector3(0.0, size.y * 0.8, 0.0), "Label")


func _marker_box(pos: Vector3, size: Vector3, color: Color, label_text: String, node_name: String = "Marker") -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _mat(color)
	_own(add_child_ex(mi))
	_label(mi, label_text, Vector3(0.0, size.y * 0.5 + 0.15, 0.0), "Label")


func _interaction_ring(center: Vector3, radius: float, group_name: String = "Ring") -> void:
	var previous_parent := _spawn_parent
	_spawn_parent = _create_group_node(group_name)

	var pillar_size := Vector3(0.12, 1.7, 0.12)
	for i in 16:
		var angle := i * TAU / 16.0
		var px := center.x + cos(angle) * radius
		var pz := center.z + sin(angle) * radius
		var mi := MeshInstance3D.new()
		mi.name = "Pillar_%02d" % [i + 1]
		mi.position = Vector3(px, pillar_size.y * 0.5, pz)
		var mesh := BoxMesh.new()
		mesh.size = pillar_size
		mi.mesh = mesh
		mi.material_override = _mat(_RANGE_COLOR)
		_own(add_child_ex(mi))

	var center_marker := MeshInstance3D.new()
	center_marker.name = "Center"
	center_marker.position = Vector3(center.x, 0.02, center.z)
	var center_mesh := CylinderMesh.new()
	center_mesh.top_radius = 0.26
	center_mesh.bottom_radius = 0.26
	center_mesh.height = 0.04
	center_marker.mesh = center_mesh
	center_marker.material_override = _mat(_WHITE)
	_own(add_child_ex(center_marker))

	_spawn_parent = previous_parent


func _meter_material(base_color: Color, width_m: float, length_m: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.92
	material.metallic = 0.02
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(maxf(width_m, 0.1), 1.0, maxf(length_m, 0.1))
	material.albedo_texture = _get_or_build_meter_texture(base_color)
	return material


func _get_or_build_meter_texture(base_color: Color) -> ImageTexture:
	var cache_key := "%0.3f_%0.3f_%0.3f_%0.3f" % [base_color.r, base_color.g, base_color.b, base_color.a]
	if _meter_texture_cache.has(cache_key):
		var cached_texture: ImageTexture = _meter_texture_cache[cache_key] as ImageTexture
		if cached_texture != null:
			return cached_texture
	var built_texture := _build_meter_texture(base_color)
	_meter_texture_cache[cache_key] = built_texture
	return built_texture


func _build_meter_texture(base_color: Color) -> ImageTexture:
	var width := 1024
	var height := 256
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(base_color)

	# Draw meter stripes every 10% of texture depth with stronger lines every 50%.
	for stripe in range(11):
		var x := int(float(stripe) / 10.0 * float(width - 1))
		var stripe_color := Color(0.95, 0.95, 0.95, 1.0) if stripe % 5 == 0 else Color(0.82, 0.82, 0.82, 1.0)
		for y in range(height):
			image.set_pixel(x, y, stripe_color)
			if x + 1 < width:
				image.set_pixel(x + 1, y, stripe_color)

	# Add a centerline so orientation is clear while moving.
	var center_y := int(height * 0.5)
	for x in range(width):
		image.set_pixel(x, center_y, Color(0.08, 0.08, 0.08, 1.0))
		if center_y + 1 < height:
			image.set_pixel(x, center_y + 1, Color(0.08, 0.08, 0.08, 1.0))

	return ImageTexture.create_from_image(image)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	return m


func _floor_label(pos: Vector3, text: String, node_name: String = "FloorLabel") -> void:
	var lbl := _label3d(node_name, pos, text, 22, Color(0.84, 0.84, 0.84))
	lbl.pixel_size = 0.0038
	_own(add_child_ex(lbl))


func _label(parent: Node3D, text: String, offset: Vector3, node_name: String = "Label") -> void:
	var lbl := _label3d(node_name, offset, text, 26, _WHITE)
	parent.add_child(lbl)
	_own(lbl)


func _label3d(name_value: String, position_value: Vector3, text_value: String, font_size: int, color: Color) -> Label3D:
	var lbl := Label3D.new()
	lbl.name = name_value
	lbl.text = text_value
	lbl.position = position_value
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.pixel_size = 0.004
	lbl.font_size = font_size
	lbl.outline_size = 6
	lbl.outline_modulate = Color.BLACK
	lbl.modulate = color
	return lbl


func _clear_generated_children() -> void:
	for child in get_children():
		var node := child as Node
		if node == null:
			continue
		var node_name := str(node.name)
		if _is_generated_top_level_node(node_name):
			node.free()


func _is_generated_top_level_node(node_name: String) -> bool:
	if node_name == "GeneratedGymMetrics":
		return true
	if node_name == "@GymGeneratedRoot":
		return true
	if node_name.begins_with("@GymGenerated"):
		return true
	if node_name.begins_with("_GymGenerated"):
		return true
	if node_name.begins_with("@StaticBody"):
		return true
	if node_name.begins_with("@Mesh"):
		return true
	if node_name.begins_with("@Label"):
		return true
	if node_name.begins_with("_StaticBody"):
		return true
	if node_name.begins_with("_Mesh"):
		return true
	if node_name.begins_with("_Label"):
		return true
	if node_name == "Zone_Instruction":
		return true
	if node_name == "Zone_Reference":
		return true
	if node_name == "Zone_JumpSets":
		return true
	if node_name == "Zone_Slopes":
		return true
	if node_name == "Zone_Steps":
		return true
	if node_name == "Zone_Range":
		return true
	return false


func _own(node: Node) -> Node:
	if not save_generated_nodes_in_scene:
		return node
	if not Engine.is_editor_hint() or not is_inside_tree():
		return node
	var root := get_tree().edited_scene_root
	if root == null:
		return node
	if root == node or root.is_ancestor_of(node):
		_apply_owner_recursive(node, root)
	return node


func _apply_owner_recursive(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		var child_node := child as Node
		if child_node != null:
			_apply_owner_recursive(child_node, owner_node)


func add_child_ex(node: Node) -> Node:
	var parent := _spawn_parent
	if parent == null:
		parent = self
	parent.add_child(node)
	return node
