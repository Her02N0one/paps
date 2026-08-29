## Gameplay host for one world context instance.
## Executes map swaps, applies spawn placement, and delegates restore lifecycles.
class_name World
extends Node3D

const PICKUP_ITEM_SCENE := preload("res://content/items/pickup_item.tscn")
const PLAYER_SCENE := preload("res://content/characters/player/player.tscn")
const PICKUP_LIFECYCLE_COMPONENT := preload("res://features/inventory/pickup_lifecycle_system.gd")
const PERSON_LIFECYCLE_COMPONENT := preload("res://features/npc/person_lifecycle_system.gd")

@export var world_ui_controller: GameUIController
@export var level_root: Node3D
@export var entity_root: Node3D
@export var player_root: Node3D
@export var effect_root: Node3D
var player: Player
var player_movement: ActorMovementSystem
var inventory: InventoryStore

var _game_manager: GameManager
var _game_state: GameState
var _save_manager
var _current_level: BaseLevel
var _pickup_lifecycle: Variant
var _person_lifecycle: Variant


func bind_services(game_manager: GameManager, game_state: GameState, save_manager) -> void:
	_game_manager = game_manager
	_game_state = game_state
	_save_manager = save_manager


func _ready() -> void:
	add_to_group("world")
	ServiceRegistry.world = self
	if _save_manager.has_method("set_world"):
		_save_manager.set_world(self)
	# All world runtime systems depend on these three shared services.
	inventory = _game_state.get_inventory()
	_ensure_runtime_player()
	world_ui_controller.quit_to_menu_requested.connect(_on_quit_to_menu_requested)
	world_ui_controller.quit_game_requested.connect(_on_quit_game_requested)
	inventory.item_dropped.connect(_on_item_dropped)
	# Player may already exist in scene or be spawned above.
	if player:
		# Player is persistent across swaps; refresh runtime bindings after each world initialization.
		player.bind_inventory(inventory)
		# Idempotent connect prevents duplicate travel callbacks.
		if not player.gateway_travel_requested.is_connected(_on_gateway_travel_requested):
			player.gateway_travel_requested.connect(_on_gateway_travel_requested)
	_pickup_lifecycle = PICKUP_LIFECYCLE_COMPONENT.new()
	_pickup_lifecycle.configure(_game_state, _save_manager, entity_root, PICKUP_ITEM_SCENE)
	_person_lifecycle = PERSON_LIFECYCLE_COMPONENT.new()
	_person_lifecycle.configure(_game_state, entity_root)
	world_ui_controller.bind_inventory_store(inventory)
	world_ui_controller.bind_dialogue_state_source(_game_state)
	world_ui_controller.set_runtime_player(player)
	world_ui_controller.start_world_session(_game_manager.consume_intro_request())
	_game_manager.on_world_ready(self)


func _ensure_runtime_player() -> void:
	var existing := player_root.get_node_or_null("Player")
	# Reuse existing player instance when scene already provides one.
	if existing and existing is Player:
		player = existing as Player
	else:
		player = PLAYER_SCENE.instantiate() as Player
		player_root.add_child(player)
		player.name = "Player"
	player_movement = ActorMovementSystem.find_on(player)


func swap_map(scene_path: String, spawn_id: String, reversed: bool = false) -> bool:
	# World owns map mutation directly in the simplified runtime path.
	return _perform_map_swap(scene_path, spawn_id, reversed)


func _perform_map_swap(scene_path: String, spawn_id: String, reversed: bool = false) -> bool:
	var packed := load(scene_path) as PackedScene
	var next_level := packed.instantiate() as BaseLevel
	_clear_transient_world()
	_current_level = next_level
	# Pickups read current_area in _ready(), so destination state must be active before attachment.
	_game_state.enter_area(scene_path)
	level_root.add_child(_current_level)
	# Place the player immediately to avoid one-frame spawn/teleport artifacts.
	_apply_entry_placement(scene_path, spawn_id, reversed)
	_restore_dynamic_pickups.call_deferred(scene_path)
	_restore_persisted_people.call_deferred(scene_path)
	_connect_static_pickups.call_deferred()
	return true


func _apply_entry_placement(scene_path: String, target_id: String, reversed: bool = false) -> void:
	if not is_instance_valid(_current_level):
		return
	if target_id.is_empty() and _try_place_player_from_saved_transform(scene_path):
		return
	_current_level.enter_level(player, target_id, reversed)
	_capture_player_transform_for_save_internal(scene_path)


func _on_quit_to_menu_requested() -> void:
	world_ui_controller.release_for_exit()
	_game_manager.quit_to_menu()


func _on_quit_game_requested() -> void:
	_save_manager.save_game("auto")
	get_tree().quit()


func _on_item_dropped(instance: ItemInstance) -> void:
	_pickup_lifecycle.drop_item_from_player(instance, player)


func _on_gateway_travel_requested(target_scene: String, gateway_id: String, reversed: bool) -> void:
	_game_manager.travel(target_scene, gateway_id, reversed)


func _restore_dynamic_pickups(area_path: String) -> void:
	_pickup_lifecycle.restore_dynamic_pickups(area_path)


func _restore_persisted_people(area_path: String) -> void:
	_person_lifecycle.restore_persisted_people(area_path, _current_level)


func _connect_static_pickups() -> void:
	# Level may be gone if another swap started before deferred restore executed.
	if not is_instance_valid(_current_level):
		return
	_pickup_lifecycle.connect_static_pickups(_current_level)


func _clear_transient_world() -> void:
	# Free old level root first so next level can attach cleanly.
	if is_instance_valid(_current_level):
		_current_level.queue_free()
	for entity in entity_root.get_children():
		entity.queue_free()
	for effect in effect_root.get_children():
		effect.queue_free()


func capture_player_transform_for_save() -> void:
	_capture_player_transform_for_save_internal(_game_state.current_area if _game_state else "")


func _capture_player_transform_for_save_internal(area_path: String) -> void:
	if area_path != _game_state.current_area:
		return
	_game_state.set_player_transform(player.global_transform)


func _try_place_player_from_saved_transform(scene_path: String) -> bool:
	if _game_state.current_area != scene_path:
		return false
	var saved := _game_state.get_player_transform()
	if typeof(saved) != TYPE_TRANSFORM3D:
		return false
	player.global_transform = saved
	player_movement.reset_facing_reference()
	return true
