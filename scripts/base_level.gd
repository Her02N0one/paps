class_name BaseLevel
extends Node3D


func get_gateway(gateway_id: String) -> Node3D:
	if gateway_id.is_empty():
		return null
	for gateway in get_tree().get_nodes_in_group("gateways"):
		if is_ancestor_of(gateway) and gateway.get("gateway_id") == gateway_id:
			return gateway as Node3D
	return null


func get_default_spawn() -> Node3D:
	for spawn in get_tree().get_nodes_in_group("spawn_points"):
		if is_ancestor_of(spawn) and spawn.get("spawn_id") == "":
			return spawn as Node3D
	return null
