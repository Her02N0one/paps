## Base map contract for spawn and gateway lookups used by World.
class_name BaseLevel
extends Node3D

const NEW_GAME_ENTRY_ID := "__new_game_entry__"

func enter_level(player: Node3D, target_id: String, reversed: bool = false) -> void:
	var movement = player.get_node("Systems/ActorMovementSystem")
	if target_id == NEW_GAME_ENTRY_ID:
		var new_game_spawn := find_new_game_spawn_point()
		movement.place_at_spawn(new_game_spawn)
		if new_game_spawn.has_method("apply_debug_player_start"):
			new_game_spawn.call("apply_debug_player_start", player)
		return
	
	if not target_id.is_empty():
		var gateway_target := find_gateway_by_id(target_id)
		var walk_start: Node3D = gateway_target.get_node_or_null("WalkStart")
		var walk_end: Node3D = gateway_target.get_node_or_null("WalkEnd")
		if walk_start and walk_end:
			movement.place_at_gateway(walk_start, walk_end, reversed)
		else:
			movement.place_at_spawn(gateway_target)
		return
		
	var fallback_spawn := find_default_spawn_point()
	movement.place_at_spawn(fallback_spawn)

func _ready() -> void:
	assert(has_node("Spawns"), "Level is missing the mandatory 'Spawns' container node.")
	assert(has_node("Gateways"), "Level is missing the mandatory 'Gateways' container node.")
	assert(has_node("Lighting"), "Level is missing the mandatory 'Lighting' container node.")
	assert(has_node("Geometry"), "Level is missing the mandatory 'Geometry' container node.")
	assert(has_node("Entities"), "Level is missing the mandatory 'Entities' container node.")
	assert(has_node("Loot"), "Level is missing the mandatory 'Loot' container node.")
	assert(has_node("Props"), "Level is missing the mandatory 'Props' container node.")
	assert(has_node("Logic"), "Level is missing the mandatory 'Logic' container node.")
	assert(has_node("Triggers"), "Level is missing the mandatory 'Triggers' container node.")

func find_gateway_by_id(gateway_id: String) -> Node3D:
	if gateway_id.is_empty():
		return null
	var gateways_container = get_node_or_null("Gateways")
	if not gateways_container:
		return null
	for node in gateways_container.get_children():
		if node is Node3D and node.is_in_group("gateways") and node.get("gateway_id") == gateway_id:
			return node as Node3D
	return null


func find_default_spawn_point() -> Node3D:
	var spawns_container = get_node_or_null("Spawns")
	if not spawns_container:
		return null
	for node in spawns_container.get_children():
		# Empty spawn_id marks the level's default fallback spawn location.
		if node is Node3D and node.is_in_group("spawn_points") and node.get("spawn_id") == "":
			return node as Node3D
	return null


func find_new_game_spawn_point() -> Node3D:
	var spawns_container = get_node_or_null("Spawns")
	if not spawns_container:
		return null
	for node in spawns_container.get_children():
		if node is Node3D and node.is_in_group("new_game_spawn_points"):
			return node as Node3D
	return null
