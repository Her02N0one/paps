## Handles pickup spawning, restore, and persistence synchronization for world runtime.
class_name PickupLifecycleComponent
extends RefCounted

const SCENE_SPAWN_SERVICE := preload("res://systems/zone_management/scene_spawn_service.gd")

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


func drop_item_from_player(data: ItemData, quantity: int, player: CharacterBody3D) -> void:
	if _game_state == null or _save_manager == null or _entity_root == null or _pickup_scene == null or player == null:
		return
	var drop_direction := -player.global_transform.basis.z.normalized()
	var drop_transform := Transform3D(Basis.IDENTITY, player.global_position + drop_direction * 1.5 + Vector3.UP)
	var dynamic_id := _game_state.add_dynamic_pickup(_game_state.current_area, data, quantity, drop_transform)
	spawn_dynamic_pickup(data, quantity, dynamic_id, drop_transform)


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
		var item := load(item_path) as ItemData if ResourceLoader.exists(item_path) else null
		var saved_transform: Variant = record.get("transform")
		if item == null or typeof(saved_transform) != TYPE_TRANSFORM3D:
			push_warning("Skipping invalid dynamic pickup %s in %s" % [dynamic_id, area_path])
			continue
		spawn_dynamic_pickup(item, int(record.get("quantity", 1)), dynamic_id, saved_transform as Transform3D)


func connect_static_pickups(level: BaseLevel) -> void:
	if level == null:
		return
	var collected_handler := Callable(self, "handle_pickup_collected")
	for child in level.find_children("*", "", true, false):
		# Connect once per pickup instance to avoid duplicate save mutations on collection.
		if child is PickupItem and not (child as PickupItem).collected.is_connected(collected_handler):
			(child as PickupItem).collected.connect(collected_handler)


func spawn_dynamic_pickup(
	data: ItemData,
	quantity: int,
	dynamic_id: String,
	spawn_transform: Transform3D
) -> void:
	if _entity_root == null or _pickup_scene == null:
		return
	# Instantiate detached, fully configure, then insert to keep node lifecycle deterministic.
	var pickup := _spawn_service.instantiate_detached_from_scene(_pickup_scene, &"PickupItem") as PickupItem
	if pickup == null:
		return
	pickup.item_data = data
	pickup.quantity = quantity
	pickup.dynamic_id = dynamic_id
	pickup.global_transform = spawn_transform
	_entity_root.add_child(pickup)
	pickup.collected.connect(Callable(self, "handle_pickup_collected"))
