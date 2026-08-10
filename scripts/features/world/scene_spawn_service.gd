## Shared spawn utility with optional runtime type contracts and override application.
class_name SceneSpawnService
extends RefCounted

const SCENE_INSTANCE_OVERRIDES := preload("res://scripts/features/world/scene_instance_overrides.gd")


func instantiate_from_scene(scene: PackedScene, parent: Node, expected_type: StringName = &"") -> Node:
	var node := instantiate_detached_from_scene(scene, expected_type)
	if node == null or parent == null:
		return null
	parent.add_child(node)
	return node


func instantiate_detached_from_scene(scene: PackedScene, expected_type: StringName = &"") -> Node:
	if scene == null:
		return null
	var node := scene.instantiate()
	if node == null:
		return null
	# Enforce expected root type early so invalid scenes never enter the live tree.
	if not expected_type.is_empty() and not _matches_expected_type(node, expected_type):
		push_warning("SceneSpawnService: expected '%s' but got '%s'." % [expected_type, node.get_class()])
		node.free()
		return null
	return node


func instantiate_from_path(scene_path: String, parent: Node, expected_type: StringName = &"") -> Node:
	var node := instantiate_detached_from_path(scene_path, expected_type)
	if node == null or parent == null:
		return null
	parent.add_child(node)
	return node


func instantiate_detached_from_path(scene_path: String, expected_type: StringName = &"") -> Node:
	if scene_path.is_empty():
		return null
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return null
	var packed := load(scene_path) as PackedScene
	return instantiate_detached_from_scene(packed, expected_type)


func _matches_expected_type(node: Node, expected_type: StringName) -> bool:
	if node.is_class(expected_type):
		return true
	# Fallback for script `class_name` hierarchies where is_class may not cover all roots.
	var script := node.get_script() as Script
	while script != null:
		if script.get_global_name() == expected_type:
			return true
		script = script.get_base_script()
	return false


func spawn_with_overrides(
	packed_scene: PackedScene,
	parent: Node,
	transform: Transform3D,
	overrides: Dictionary = {},
	expected_type: StringName = &""
) -> Node3D:
	var spawned := instantiate_from_scene(packed_scene, parent, expected_type)
	if not (spawned is Node3D):
		return null
	var node_3d := spawned as Node3D
	node_3d.global_transform = transform
	# Apply overrides after transform to preserve any explicit positional values in overrides.
	SCENE_INSTANCE_OVERRIDES.apply(node_3d, overrides)
	return node_3d