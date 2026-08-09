class_name Interactable
extends StaticBody3D

@export var interact_label: String = "Interact"

static var _highlight_mat: StandardMaterial3D = null


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0


# Override in subclasses to define behavior.
func interact(_player: Node3D) -> void:
	pass


func _highlight() -> void:
	if not _highlight_mat:
		_highlight_mat = StandardMaterial3D.new()
		_highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_highlight_mat.albedo_color = Color(1.0, 0.9, 0.2, 0.25)
		_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_highlight_mat.no_depth_test = true
	for child in get_children():
		if child is MeshInstance3D:
			child.material_overlay = _highlight_mat


func _unhighlight() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			child.material_overlay = null
