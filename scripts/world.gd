extends Node3D

const PICKUP_ITEM_SCENE := preload("res://scenes/pickup_item.tscn")

@onready var ui_coordinator: GameUIController = $Systems/UICoordinator
@onready var level_root: Node3D = $GameplayWorld/LevelRoot
@onready var entity_root: Node3D = $GameplayWorld/EntityRoot
@onready var effect_root: Node3D = $GameplayWorld/EffectRoot
@onready var player: CharacterBody3D = $GameplayWorld/EntityRoot/Player
@onready var player_movement: ActorMovementComponent = ActorMovementComponent.find_on(player)

var _current_level: BaseLevel


func _ready() -> void:
	add_to_group("world")
	ui_coordinator.quit_to_menu_requested.connect(_on_quit_to_menu_requested)
	ui_coordinator.quit_game_requested.connect(_on_quit_game_requested)
	get_node("/root/Inventory").item_dropped.connect(_on_item_dropped)
	ui_coordinator.begin_session(GameManager.consume_intro_request())
	GameManager.on_world_ready(self)


func swap_map(scene_path: String, spawn_id: String, reversed: bool = false) -> bool:
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_error("Level scene does not exist: %s" % scene_path)
		return false
	var packed_level := load(scene_path) as PackedScene
	var next_level := packed_level.instantiate() as BaseLevel if packed_level else null
	if next_level == null:
		push_error("Scene does not implement BaseLevel: %s" % scene_path)
		return false
	_clear_transient_world()
	_current_level = next_level
	# Pickups read current_area in _ready(), so destination state must be active before attachment.
	GameState.enter_area(scene_path)
	level_root.add_child(_current_level)
	_apply_spawn.call_deferred(spawn_id, reversed)
	_restore_dynamic_pickups.call_deferred(scene_path)
	SaveManager.save_game()
	return true


func _apply_spawn(target_id: String, reversed: bool = false) -> void:
	if not is_instance_valid(_current_level):
		return
	if player_movement == null:
		push_error("The active player has no ActorMovementComponent and cannot be placed.")
		return
	var target: Node3D = _current_level.get_gateway(target_id)
	var is_gateway := target != null
	if target == null:
		target = _current_level.get_default_spawn()
	if target == null:
		push_error("Level '%s' has no valid spawn for '%s'." % [_current_level.name, target_id])
		return
	if is_gateway:
		var walk_start: Node3D = target.get_node_or_null("WalkStart")
		var walk_end: Node3D = target.get_node_or_null("WalkEnd")
		if walk_start and walk_end:
			player_movement.place_at_gateway(walk_start, walk_end, reversed)
		else:
			player_movement.place_at_spawn(target)
	else:
		player_movement.place_at_spawn(target)


func _on_quit_to_menu_requested() -> void:
	GameManager.quit_to_menu()


func _on_quit_game_requested() -> void:
	SaveManager.save_game()
	get_tree().quit()


func _on_item_dropped(data: ItemData, quantity: int) -> void:
	var drop_direction := -player.global_transform.basis.z.normalized()
	var drop_transform := Transform3D(Basis.IDENTITY, player.global_position + drop_direction * 1.5 + Vector3.UP)
	var dynamic_id := GameState.add_dynamic_pickup(GameState.current_area, data, quantity, drop_transform)
	_spawn_dynamic_pickup(data, quantity, dynamic_id, drop_transform)
	SaveManager.save_game()


func _restore_dynamic_pickups(area_path: String) -> void:
	var dynamic_pickups := GameState.get_dynamic_pickups(area_path)
	for dynamic_id in dynamic_pickups:
		var record: Dictionary = dynamic_pickups[dynamic_id]
		var item_path := str(record.get("item_path", ""))
		var item := load(item_path) as ItemData if ResourceLoader.exists(item_path) else null
		var saved_transform = record.get("transform")
		if item == null or typeof(saved_transform) != TYPE_TRANSFORM3D:
			push_warning("Skipping invalid dynamic pickup %s in %s" % [dynamic_id, area_path])
			continue
		_spawn_dynamic_pickup(item, int(record.get("quantity", 1)), dynamic_id, saved_transform)


func _clear_transient_world() -> void:
	if is_instance_valid(_current_level):
		_current_level.queue_free()
	for entity in entity_root.get_children():
		if entity != player:
			entity.queue_free()
	for effect in effect_root.get_children():
		effect.queue_free()


func _spawn_dynamic_pickup(data: ItemData, quantity: int, dynamic_id: String, spawn_transform: Transform3D) -> void:
	var pickup: PickupItem = PICKUP_ITEM_SCENE.instantiate()
	pickup.item_data = data
	pickup.quantity = quantity
	pickup.dynamic_id = dynamic_id
	entity_root.add_child(pickup)
	pickup.global_transform = spawn_transform
