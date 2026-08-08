extends Marker3D

## This gateway's ID - what other gateways set as their target_gateway_id to land here.
@export var gateway_id: String = ""
@export_file("*.tscn") var target_scene: String = ""
## gateway_id of the landing gateway in target_scene.
@export var target_gateway_id: String = ""
@export var trigger_size: Vector3 = Vector3(4, 3, 2)

var _triggered := false


func _ready() -> void:
	add_to_group("gateways")
	_build_trigger()
	_build_visual()


func _build_trigger() -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	add_child(area)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = trigger_size
	col.shape = box
	area.add_child(col)
	area.body_entered.connect(_on_body_entered)


func _build_visual() -> void:
	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = trigger_size
	mesh_inst.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.75, 1.0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	add_child(mesh_inst)


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not _triggered:
		_triggered = true
		GameManager.travel(target_scene, target_gateway_id)
