## Gameplay host for one world context instance.
## Executes map swaps, applies spawn placement, and delegates restore lifecycles.
class_name World
extends Node3D

const NEW_GAME_ENTRY_ID := "__new_game_entry__"
const NEW_GAME_ENTRY_PREFIX := "__new_game_entry__:"

const PICKUP_ITEM_SCENE := preload("res://entities/items/pickup_item/pickup_item.tscn")
const PLAYER_SCENE := preload("res://entities/characters/player/player.tscn")
const PICKUP_LIFECYCLE_COMPONENT := preload("res://entities/items/search_object/pickup_lifecycle_component.gd")
const PERSON_LIFECYCLE_COMPONENT := preload("res://entities/characters/base_npc/person_lifecycle_component.gd")
const SCENE_SPAWN_SERVICE := preload("res://core/zone_management/scene_spawn_service.gd")

@onready var world_ui_controller: GameUIController = $WorldUI
@onready var level_root: Node3D = $GameplayWorld/LevelRoot
@onready var entity_root: Node3D = $GameplayWorld/EntityRoot
@onready var effect_root: Node3D = $GameplayWorld/EffectRoot
var player: Player
var player_movement: ActorMovementComponent
var inventory: InventoryStore

var _game_manager: GameManager
var _game_state: GameState
var _save_manager
var _current_level: BaseLevel
var _pickup_lifecycle: Variant
var _person_lifecycle: Variant
var _spawn_service: SceneSpawnService


func bind_services(game_manager: GameManager, game_state: GameState, save_manager) -> void:
	_game_manager = game_manager
	_game_state = game_state
	_save_manager = save_manager


func _ready() -> void:
	add_to_group("world")
	# All world runtime systems depend on these three shared services.
	if _game_manager == null or _game_state == null or _save_manager == null:
		push_error("World services are not bound. Call bind_services() before adding World to the tree.")
		return
	_spawn_service = SCENE_SPAWN_SERVICE.new()
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
	var existing := entity_root.get_node_or_null("Player")
	# Reuse existing player instance when scene already provides one.
	if existing and existing is Player:
		player = existing as Player
	else:
		# Spawn through the shared service so class-name root checks stay consistent project-wide.
		player = _spawn_service.instantiate_from_scene(PLAYER_SCENE, entity_root, &"Player") as Player
		# Without a player the world cannot proceed with spawn/travel behaviors.
		if player == null:
			push_error("Unable to instantiate runtime player scene.")
			return
		player.name = "Player"
		player.refresh_body_profile()
	player_movement = ActorMovementComponent.find_on(player)


func swap_map(scene_path: String, spawn_id: String, reversed: bool = false) -> bool:
	# World owns map mutation directly in the simplified runtime path.
	return _perform_map_swap(scene_path, spawn_id, reversed)


func _perform_map_swap(scene_path: String, spawn_id: String, reversed: bool = false) -> bool:
	var next_level := _spawn_service.instantiate_detached_from_path(scene_path, &"BaseLevel") as BaseLevel
	# Invalid level scene path or type rejects swap before any world mutation.
	if next_level == null:
		push_error("Scene is missing or does not implement BaseLevel: %s" % scene_path)
		return false
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
	# Deferred callbacks may run after level has already been replaced/freed.
	if not is_instance_valid(_current_level):
		return
	# Spawn placement requires movement component on active player.
	if player_movement == null:
		push_error("The active player has no ActorMovementComponent and cannot be placed.")
		return
	if target_id == NEW_GAME_ENTRY_ID or target_id.begins_with(NEW_GAME_ENTRY_PREFIX):
		var new_game_marker_id := _extract_new_game_marker_id(target_id)
		var new_game_spawn := _current_level.find_new_game_spawn_point(new_game_marker_id)
		if new_game_spawn == null:
			push_error("Level '%s' is missing a NewGameSpawnPoint marker%s." % [_current_level.name, (" for '%s'" % new_game_marker_id) if not new_game_marker_id.is_empty() else ""])
			return
		player_movement.place_at_spawn(new_game_spawn)
		var spawn_point := new_game_spawn as NewGameSpawnPoint
		if spawn_point:
			new_game_spawn.call("apply_debug_player_start", player)
		_capture_player_transform_for_save_internal(scene_path)
		return
	if not target_id.is_empty():
		var gateway_target := _current_level.find_gateway_by_id(target_id)
		if gateway_target == null:
			push_error("Level '%s' has no gateway matching '%s'." % [_current_level.name, target_id])
			return
		var walk_start: Node3D = gateway_target.get_node_or_null("WalkStart")
		var walk_end: Node3D = gateway_target.get_node_or_null("WalkEnd")
		if walk_start and walk_end:
			player_movement.place_at_gateway(walk_start, walk_end, reversed)
		else:
			player_movement.place_at_spawn(gateway_target)
		_capture_player_transform_for_save_internal(scene_path)
		return
	if _try_place_player_from_saved_transform(scene_path):
		return
	var fallback_spawn := _current_level.find_default_spawn_point()
	if fallback_spawn:
		player_movement.place_at_spawn(fallback_spawn)
		_capture_player_transform_for_save_internal(scene_path)
		return
	push_error("Level '%s' has no valid entry placement." % _current_level.name)


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
		# Preserve the runtime player node; non-player entities are area-local.
		if entity != player:
			entity.queue_free()
	for effect in effect_root.get_children():
		effect.queue_free()


func capture_player_transform_for_save() -> void:
	_capture_player_transform_for_save_internal(_game_state.current_area if _game_state else "")


func _capture_player_transform_for_save_internal(area_path: String) -> void:
	if _game_state == null or player == null:
		return
	if area_path != _game_state.current_area:
		return
	_game_state.set_player_transform(player.global_transform)


func _try_place_player_from_saved_transform(scene_path: String) -> bool:
	if _game_state == null or player == null:
		return false
	if _game_state.current_area != scene_path:
		return false
	var saved := _game_state.get_player_transform()
	if typeof(saved) != TYPE_TRANSFORM3D:
		return false
	player.global_transform = saved
	player_movement.reset_facing_reference()
	return true


func _extract_new_game_marker_id(target_id: String) -> StringName:
	if not target_id.begins_with(NEW_GAME_ENTRY_PREFIX):
		return &""
	var marker_id := target_id.substr(NEW_GAME_ENTRY_PREFIX.length())
	return StringName(marker_id)
