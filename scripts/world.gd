extends Node3D

const PICKUP_ITEM_SCENE := preload("res://scenes/pickup_item.tscn")

@onready var ui_coordinator: GameUIController = $Systems/UICoordinator
@onready var level_root: Node3D = $GameplayWorld/LevelRoot
@onready var entity_root: Node3D = $GameplayWorld/EntityRoot
@onready var effect_root: Node3D = $GameplayWorld/EffectRoot
@onready var player: CharacterBody3D = $GameplayWorld/EntityRoot/Player

var _current_level: BaseLevel


func _ready() -> void:
	add_to_group("world")
	ui_coordinator.quit_to_menu_requested.connect(_on_quit_to_menu_requested)
	ui_coordinator.quit_game_requested.connect(_on_quit_game_requested)
	get_node("/root/Inventory").item_dropped.connect(_on_item_dropped)
	ui_coordinator.begin_session(GameManager.consume_intro_request())
	GameManager.on_world_ready(self)


# Validates and replaces the active level while preserving stable world roots.
func swap_map(scene_path: String, spawn_id: String, reversed: bool = false) -> bool:
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_error("Level scene does not exist: %s" % scene_path)
		return false
	var packed_level := load(scene_path) as PackedScene
	var next_level := packed_level.instantiate() as BaseLevel if packed_level else null
	if next_level == null:
		push_error("Scene does not implement BaseLevel: %s" % scene_path)
		return false
	if is_instance_valid(_current_level):
		_current_level.queue_free()
	for entity in entity_root.get_children():
		if entity != player:
			entity.queue_free()
	for effect in effect_root.get_children():
		effect.queue_free()
	_current_level = next_level
	level_root.add_child(_current_level)
	GameState.enter_area(scene_path)
	_apply_spawn.call_deferred(spawn_id, reversed)
	_restore_dynamic_pickups.call_deferred(scene_path)
	SaveManager.save_game()
	return true


func _apply_spawn(target_id: String, reversed: bool = false) -> void:
	if not is_instance_valid(_current_level):
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
			var walk_dir := (walk_end.global_position - walk_start.global_position).normalized()
			var dist: float = walk_start.global_position.distance_to(walk_end.global_position)
			player.global_position = walk_start.global_position
			# reversed: face back toward the gateway, still walk in same direction (backing away)
			player.rotation.y = atan2(walk_dir.x, walk_dir.z) if reversed else atan2(-walk_dir.x, -walk_dir.z)
			player.get_node("Head").rotation.y = 0.0
			player.start_arrival_walk(walk_dir, dist)
		else:
			player.global_position = target.global_position
			player.get_node("Head").rotation.y = 0.0
	else:
		player.global_position = target.global_position
		player.rotation.y = target.rotation.y
		player.get_node("Head").rotation.y = 0.0


func _on_quit_to_menu_requested() -> void:
	GameManager.quit_to_menu()


func _on_quit_game_requested() -> void:
	SaveManager.save_game()
	get_tree().quit()


func _on_item_dropped(data: ItemData, quantity: int) -> void:
	var pickup: PickupItem = PICKUP_ITEM_SCENE.instantiate()
	pickup.item_data = data
	pickup.quantity = quantity
	var drop_direction := -player.global_transform.basis.z.normalized()
	var drop_transform := Transform3D(Basis.IDENTITY, player.global_position + drop_direction * 1.5 + Vector3.UP)
	pickup.dynamic_id = GameState.add_dynamic_pickup(GameState.current_area, data, quantity, drop_transform)
	entity_root.add_child(pickup)
	pickup.global_transform = drop_transform
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
		var pickup: PickupItem = PICKUP_ITEM_SCENE.instantiate()
		pickup.item_data = item
		pickup.quantity = int(record.get("quantity", 1))
		pickup.dynamic_id = dynamic_id
		entity_root.add_child(pickup)
		pickup.global_transform = saved_transform
