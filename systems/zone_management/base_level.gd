## Base map contract for spawn and gateway lookups used by World.
class_name BaseLevel
extends Node3D


func find_gateway_by_id(gateway_id: String) -> Node3D:
	if gateway_id.is_empty():
		return null
	# Search recursively so level internals can be reorganized without API changes.
	for node in find_children("*", "Node", true, false):
		if node is Node3D and node.is_in_group("gateways") and node.get("gateway_id") == gateway_id:
			return node as Node3D
	return null


func find_default_spawn_point() -> Node3D:
	for node in find_children("*", "Node", true, false):
		# Empty spawn_id marks the level's default fallback spawn location.
		if node is Node3D and node.is_in_group("spawn_points") and node.get("spawn_id") == "":
			return node as Node3D
	return null


func find_new_game_spawn_point(marker_id: StringName = &"") -> Node3D:
	if not marker_id.is_empty():
		for node in find_children("*", "Node", true, false):
			if node is Node3D and node.is_in_group("new_game_spawn_points") and node.get("marker_id") == marker_id:
				return node as Node3D
	for node in find_children("*", "Node", true, false):
		if node is Node3D and node.is_in_group("new_game_spawn_points"):
			return node as Node3D
	# Keep older maps functional until they get an explicit new-game marker.
	return find_default_spawn_point()
