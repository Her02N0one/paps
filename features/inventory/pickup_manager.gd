extends Node
class_name PickupManager

var _next_dynamic_id := 1

func _ready() -> void:
	pass

func configure_hooks(save_manager: SaveManager) -> void:
	if not save_manager.about_to_save.is_connected(_on_about_to_save):
		save_manager.about_to_save.connect(_on_about_to_save)
	if not save_manager.game_loaded.is_connected(_on_game_loaded):
		save_manager.game_loaded.connect(_on_game_loaded)

func _on_about_to_save() -> void:
	var gs = ServiceRegistry.game_state
	if gs:
		gs.global_flags["pickup_manager_next_id"] = _next_dynamic_id

func _on_game_loaded() -> void:
	var gs = ServiceRegistry.game_state
	if gs and gs.global_flags.has("pickup_manager_next_id"):
		_next_dynamic_id = maxi(int(gs.global_flags["pickup_manager_next_id"]), 1)
	else:
		_next_dynamic_id = 1

func is_static_pickup_collected(area_path: String, persistent_id: String) -> bool:
	if persistent_id.is_empty():
		return false
	var gs = ServiceRegistry.game_state
	if not gs: return false
	var area := gs._ensure_area(area_path)
	return persistent_id in area.removed_static_pickups

func collect_static_pickup(area_path: String, persistent_id: String) -> void:
	if persistent_id.is_empty():
		return
	var gs = ServiceRegistry.game_state
	if not gs: return
	var area := gs._ensure_area(area_path)
	if persistent_id not in area.removed_static_pickups:
		area.removed_static_pickups.append(persistent_id)
		gs.state_changed.emit()

func add_dynamic_pickup(area_path: String, definition: ItemDefinition, quantity: int, transform: Transform3D) -> String:
	if definition == null or definition.resource_path.is_empty() or quantity <= 0:
		return ""
	var dynamic_id := "drop_%d" % _next_dynamic_id
	_next_dynamic_id += 1
	var gs = ServiceRegistry.game_state
	if not gs: return ""
	var area := gs._ensure_area(area_path)
	area.dynamic_pickups[dynamic_id] = {
		"item_path": definition.resource_path,
		"quantity": quantity,
		"transform": transform,
	}
	gs.state_changed.emit()
	return dynamic_id

func remove_dynamic_pickup(area_path: String, dynamic_id: String) -> void:
	var gs = ServiceRegistry.game_state
	if not gs: return
	var area := gs._ensure_area(area_path)
	if area.dynamic_pickups.erase(dynamic_id):
		gs.state_changed.emit()

func get_dynamic_pickups(area_path: String) -> Dictionary:
	var gs = ServiceRegistry.game_state
	if not gs: return {}
	return gs._ensure_area(area_path).dynamic_pickups.duplicate(true)
