class_name SaveableComponent
extends Node

## Whether this object's state is global (persists everywhere) or local to the current scene.
enum SaveScope { GLOBAL, SCENE_LOCAL }

@export var scope: SaveScope = SaveScope.SCENE_LOCAL
@export var unique_id: String = ""
@export var properties_to_save: Array[String] = []

var _game_state: GameState


func _ready() -> void:
	add_to_group("saveable")
	_game_state = get_tree().get_first_node_in_group("game_state") as GameState
	if _game_state == null:
		return
		
	if unique_id.is_empty():
		push_error("SaveableComponent on %s has no unique_id defined!" % get_parent().name)
		return
		
	_load_state()


func _exit_tree() -> void:
	_save_state()


func _load_state() -> void:
	var data := _get_store()
	if data.has(unique_id):
		var saved_values: Dictionary = data[unique_id]
		var parent = get_parent()
		for prop in properties_to_save:
			if saved_values.has(prop):
				parent.set(prop, saved_values[prop])


func _save_state() -> void:
	if _game_state == null or unique_id.is_empty():
		return
		
	var saved_values := {}
	var parent = get_parent()
	for prop in properties_to_save:
		saved_values[prop] = parent.get(prop)
		
	var data := _get_store()
	data[unique_id] = saved_values


func _get_store() -> Dictionary:
	if _game_state == null:
		return {}
		
	if scope == SaveScope.GLOBAL:
		# Use global_flags dictionary for generic global state
		return _game_state.global_flags
	else:
		var area = _game_state.current_area
		if not _game_state._areas.has(area):
			_game_state._areas[area] = {"removed_static_pickups": [], "dynamic_pickups": {}, "components": {}}
		if not _game_state._areas[area].has("components"):
			_game_state._areas[area]["components"] = {}
		return _game_state._areas[area]["components"]
