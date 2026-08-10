## Applies serialized per-instance overrides after scene instantiation.
class_name SceneInstanceOverrides
extends RefCounted


static func apply(instance_root: Node, overrides: Dictionary) -> void:
	if instance_root == null or overrides.is_empty():
		return
	_apply_property_overrides(instance_root, overrides.get("properties", []))
	_apply_method_calls(instance_root, overrides.get("method_calls", []))


static func _apply_property_overrides(instance_root: Node, raw_entries: Variant) -> void:
	if not raw_entries is Array:
		return
	for raw_entry in raw_entries:
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		var target := _resolve_target(instance_root, str(entry.get("node_path", "")))
		var property := StringName(str(entry.get("property", "")))
		if target == null or property.is_empty():
			continue
		# Validate property existence first so stale override payloads fail gracefully.
		if not _has_property(target, property):
			push_warning("SceneInstanceOverrides: '%s' has no property '%s'." % [target.name, property])
			continue
		target.set(property, entry.get("value"))


static func _apply_method_calls(instance_root: Node, raw_entries: Variant) -> void:
	if not raw_entries is Array:
		return
	for raw_entry in raw_entries:
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		var target := _resolve_target(instance_root, str(entry.get("node_path", "")))
		var method := StringName(str(entry.get("method", "")))
		if target == null or method.is_empty():
			continue
		# Guard missing methods so old payload versions do not break scene restore.
		if not target.has_method(method):
			push_warning("SceneInstanceOverrides: '%s' has no method '%s'." % [target.name, method])
			continue
		var args: Variant = entry.get("args", [])
		target.callv(method, args if args is Array else [])


static func _resolve_target(instance_root: Node, node_path: String) -> Node:
	if node_path.is_empty() or node_path == ".":
		return instance_root
	return instance_root.get_node_or_null(NodePath(node_path))


static func _has_property(target: Object, property: StringName) -> bool:
	for prop in target.get_property_list():
		if prop is Dictionary and StringName(prop.get("name", "")) == property:
			return true
	return false