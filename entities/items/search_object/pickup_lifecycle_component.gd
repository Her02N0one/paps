## Handles pickup spawning, restore, and persistence synchronization for world runtime.
class_name PickupLifecycleComponent
extends RefCounted

const SCENE_SPAWN_SERVICE := preload("res://core/zone_management/scene_spawn_service.gd")

var _game_state: GameState
var _save_manager
var _entity_root: Node3D
var _pickup_scene: PackedScene
var _spawn_service: SceneSpawnService


func configure(game_state: GameState, save_manager, entity_root: Node3D, pickup_scene: PackedScene) -> void:
	_game_state = game_state
	_save_manager = save_manager
	_entity_root = entity_root
	_pickup_scene = pickup_scene
	_spawn_service = SCENE_SPAWN_SERVICE.new()


func drop_item_from_player(instance: ItemInstance, player: CharacterBody3D) -> void:
	if _game_state == null or _save_manager == null or _entity_root == null or _pickup_scene == null or player == null:
		return
	var drop_direction := -player.global_transform.basis.z.normalized()
	# Spawn 1.5 units forward, 1.5 units up to completely clear the player's collision hull
	var drop_transform := Transform3D(Basis.IDENTITY, player.global_position + drop_direction * 1.5 + Vector3(0, 1.5, 0))
	# TODO: in the future, GameState needs to store serialized ItemInstances instead of just definition paths.
	var dynamic_id := _game_state.add_dynamic_pickup(_game_state.current_area, instance.definition, instance.quantity, drop_transform)
	spawn_dynamic_pickup(instance, dynamic_id, drop_transform)


func handle_pickup_collected(persistent_id: String, dynamic_id: String) -> void:
	if _game_state == null or _save_manager == null:
		return
	if not dynamic_id.is_empty():
		_game_state.remove_dynamic_pickup(_game_state.current_area, dynamic_id)
	elif not persistent_id.is_empty():
		_game_state.collect_static_pickup(_game_state.current_area, persistent_id)


func restore_dynamic_pickups(area_path: String) -> void:
	if _game_state == null:
		return
	var dynamic_pickups := _game_state.get_dynamic_pickups(area_path)
	for dynamic_id in dynamic_pickups:
		var record: Dictionary = dynamic_pickups[dynamic_id]
		var item_path := str(record.get("item_path", ""))
		# Validate resource and transform per record so one corrupt entry does not block others.
		var item := load(item_path) as ItemDefinition if ResourceLoader.exists(item_path) else null
		var saved_transform: Variant = record.get("transform")
		if item == null or typeof(saved_transform) != TYPE_TRANSFORM3D:
			push_warning("Skipping invalid dynamic pickup %s in %s" % [dynamic_id, area_path])
			continue
		var instance = ItemInstance.new(item, int(record.get("quantity", 1)))
		spawn_dynamic_pickup(instance, dynamic_id, saved_transform as Transform3D)


func connect_static_pickups(level: BaseLevel) -> void:
	if level == null:
		return
	var collected_handler := Callable(self, "handle_pickup_collected")
	for child in level.find_children("*", "", true, false):
		if child is SearchObject and not (child as SearchObject).collected.is_connected(collected_handler):
			(child as SearchObject).collected.connect(collected_handler)
		elif child is PickupItem and not (child as PickupItem).collected.is_connected(collected_handler):
			(child as PickupItem).collected.connect(collected_handler)


func spawn_dynamic_pickup(
	instance: ItemInstance,
	dynamic_id: String,
	spawn_transform: Transform3D
) -> void:
	if _entity_root == null or _pickup_scene == null:
		return
	var pickup := _spawn_service.instantiate_detached_from_scene(_pickup_scene, &"PickupItem") as PickupItem
	if pickup == null:
		return
	pickup.instance = instance
	pickup.dynamic_id = dynamic_id
	
	_entity_root.add_child(pickup)
	pickup.global_position = spawn_transform.origin
	pickup.basis = spawn_transform.basis
	
	pickup.collected.connect(Callable(self, "handle_pickup_collected"))
