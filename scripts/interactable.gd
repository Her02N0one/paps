class_name Interactable
extends Node

const OUTLINE_SHADER := preload("res://shaders/interaction_outline.gdshader")

signal interact(actor: Node3D)

@export var interact_label: String = "Interact"
@export var highlight_root: Node3D
@export var outline_color := Color(1.0, 0.85, 0.15)
@export_range(0.0, 0.25, 0.001) var outline_width := 0.035

var _outline_material: ShaderMaterial
var _outline_meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	var collision_object := get_parent() as CollisionObject3D
	if collision_object:
		collision_object.collision_layer = 2
		collision_object.collision_mask = 0


func activate(actor: Node3D) -> void:
	interact.emit(actor)


func get_visual_center() -> Vector3:
	var meshes := _get_meshes()
	if meshes.is_empty():
		var parent_3d := get_parent() as Node3D
		return parent_3d.global_position if parent_3d else Vector3.ZERO
	var bounds := meshes[0].global_transform * meshes[0].get_aabb()
	for index in range(1, meshes.size()):
		bounds = bounds.merge(meshes[index].global_transform * meshes[index].get_aabb())
	return bounds.get_center()


func highlight() -> void:
	if not _outline_meshes.is_empty():
		return
	if _outline_material == null:
		_outline_material = _create_outline_material()
	for mesh in _get_meshes():
		_outline_meshes.append(_create_outline_mesh(mesh))


func unhighlight() -> void:
	for outline in _outline_meshes:
		if is_instance_valid(outline):
			outline.queue_free()
	_outline_meshes.clear()


func _create_outline_mesh(source: MeshInstance3D) -> MeshInstance3D:
	var outline := MeshInstance3D.new()
	outline.name = "InteractionOutline"
	outline.mesh = source.mesh
	outline.skin = source.skin
	outline.layers = source.layers
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline.extra_cull_margin = outline_width
	outline.material_override = _outline_material
	outline.set_meta(&"interaction_outline", true)
	if not source.skeleton.is_empty():
		outline.skeleton = NodePath("../" + str(source.skeleton))
	for index in source.get_blend_shape_count():
		outline.set_blend_shape_value(index, source.get_blend_shape_value(index))
	source.add_child(outline)
	return outline


func _create_outline_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter(&"outline_color", outline_color)
	material.set_shader_parameter(&"outline_width", outline_width)
	return material


static func find_on(collider: Node) -> Interactable:
	if collider == null:
		return null
	if collider is Interactable:
		return collider as Interactable
	for child in collider.get_children():
		if child is Interactable:
			return child as Interactable
	return null


func _get_meshes() -> Array[MeshInstance3D]:
	var root := highlight_root if highlight_root != null else get_parent()
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D and _is_outline_source(root):
		meshes.append(root)
	if root:
		for child in root.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			if _is_outline_source(mesh):
				meshes.append(mesh)
	return meshes


func _is_outline_source(mesh: MeshInstance3D) -> bool:
	return mesh.mesh != null and not mesh.is_queued_for_deletion() and not mesh.has_meta(&"interaction_outline")
