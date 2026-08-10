## Base interaction surface with optional visual highlighting and request emission.
class_name Interactable
extends Node

const OUTLINE_SHADER := preload("res://shaders/interaction_outline.gdshader")

signal interact(actor: Node3D)
signal player_interaction_requested(request: PlayerInteractionRequest)

@export var interact_label: String = "Interact"
@export var highlight_root: Node3D
@export var outline_color := Color(1.0, 0.85, 0.15)
@export_range(0.0, 0.25, 0.001) var outline_width := 0.035

var _outline_material: ShaderMaterial
var _outline_meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	var collision_object := get_parent() as CollisionObject3D
	# Standardize interaction collision filtering when parent is a collision object.
	if collision_object:
		collision_object.collision_layer = 2
		collision_object.collision_mask = 0


func activate(actor: Node3D) -> void:
	interact.emit(actor)


func request_player_interaction(action: StringName, actor: Node3D, payload: Dictionary = {}) -> void:
	player_interaction_requested.emit(PlayerInteractionRequest.new(action, actor, self, payload))


func get_visual_center() -> Vector3:
	var highlight_meshes := _find_highlight_meshes()
	# Fallback to parent position when no visual mesh can provide bounds.
	if highlight_meshes.is_empty():
		var parent_3d := get_parent() as Node3D
		return parent_3d.global_position if parent_3d else Vector3.ZERO
	var bounds := highlight_meshes[0].global_transform * highlight_meshes[0].get_aabb()
	# Merge all candidate mesh bounds to produce one stable aim/highlight center.
	for index in range(1, highlight_meshes.size()):
		bounds = bounds.merge(highlight_meshes[index].global_transform * highlight_meshes[index].get_aabb())
	return bounds.get_center()


func highlight() -> void:
	# Reuse one outline set until explicitly unhighlighted.
	if not _outline_meshes.is_empty():
		return
	# Lazily allocate material so idle interactables do not pay setup cost.
	if _outline_material == null:
		_outline_material = _create_outline_material()
	for mesh in _find_highlight_meshes():
		_outline_meshes.append(_create_outline_mesh(mesh))


func unhighlight() -> void:
	for outline in _outline_meshes:
		# Outline children may already be freed by scene teardown.
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
	# Skinned meshes need skeleton path rewired relative to the new child node.
	if not source.skeleton.is_empty():
		# The outline is parented below the source, so its skeleton path needs one extra parent hop.
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
	# Null collider means no host to inspect.
	if collider == null:
		return null
	# Fast path when collider itself is an interactable node.
	if collider is Interactable:
		return collider as Interactable
	for child in collider.get_children():
		# First interactable child wins.
		if child is Interactable:
			return child as Interactable
	return null


func _find_highlight_meshes() -> Array[MeshInstance3D]:
	var root := highlight_root if highlight_root != null else get_parent()
	var meshes: Array[MeshInstance3D] = []
	# Include root directly when it is itself a valid highlight mesh.
	if root is MeshInstance3D and _is_highlight_source_mesh(root):
		meshes.append(root)
	if root:
		# Recursive mesh discovery allows prefab internals to move without updating hardcoded paths.
		for child in root.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			# Filter to source meshes only; generated outlines are excluded.
			if _is_highlight_source_mesh(mesh):
				meshes.append(mesh)
	return meshes


func _is_highlight_source_mesh(mesh: MeshInstance3D) -> bool:
	# Generated outline children carry metadata so they are not outlined recursively.
	return mesh.mesh != null and not mesh.is_queued_for_deletion() and not mesh.has_meta(&"interaction_outline")
