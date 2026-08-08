extends Area3D

@export_file("*.tscn") var target_scene: String = ""
@export var target_spawn_id: String = ""


func _ready() -> void:
	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(6, 4, 0.2)
	mesh_inst.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.75, 1.0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	add_child(mesh_inst)


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		GameManager.travel(target_scene, target_spawn_id)
