## Basic file IO for game state saving and loading.
class_name SaveManager
extends Node

signal save_completed(filename: String, success: bool)
signal load_completed(filename: String, success: bool)

const SAVE_DIRECTORY := "user://saves"

var _active_filename := ""
var _loading := false
var _game_state: GameState
var _inventory: InventoryStore


func _ready() -> void:
	var error := DirAccess.make_dir_recursive_absolute(SAVE_DIRECTORY)
	if error != OK:
		push_error("Unable to create save directory: %s" % error_string(error))


func configure(game_state: GameState, inventory: InventoryStore) -> void:
	_game_state = game_state
	_inventory = inventory


func start_new_game(initial_area: String) -> bool:
	if _game_state == null:
		return false
	_active_filename = ""
	_loading = true
	_game_state.reset(initial_area)
	_loading = false
	return true


func has_save() -> bool:
	return get_all_saves().size() > 0


func save_game(type: String, save_name: String = "") -> bool:
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("capture_player_transform_for_save"):
		world.call("capture_player_transform_for_save")
		
	if _game_state == null or _game_state.current_area.is_empty():
		save_completed.emit("", false)
		return false
		
	if save_name.is_empty():
		var area_name = _game_state.current_area.get_file().get_basename().capitalize() if not _game_state.current_area.is_empty() else "Unknown"
		var time_str = _game_state.get_in_game_time_string() if _game_state.has_method("get_in_game_time_string") else "DAY 1, 12-00"
		if type == "auto":
			save_name = "AUTOSAVE, %s, %s" % [area_name, time_str]
		elif type == "quick":
			save_name = "QUICKSAVE"
		else:
			save_name = "%s, %s" % [area_name, time_str]
			
	var filename = _get_filename_for_save(type, save_name)
	var payload := {
		"metadata": {
			"saved_at_unix": int(Time.get_unix_time_from_system()),
			"saved_at_utc": Time.get_datetime_string_from_system(true),
			"application_version": str(ProjectSettings.get_setting("application/config/version", "development")),
			"save_type": type,
			"save_name": save_name.to_upper(),
			"filename": filename
		},
		"global_game_state": _game_state.to_global_save_data(),
		"scene_game_state": _game_state.to_scene_save_data(),
	}
	
	var success := _write_payload(filename, payload)
	if success:
		_active_filename = filename
	save_completed.emit(filename, success)
	return success


func trigger_autosave() -> void:
	if _loading or _game_state == null or _game_state.current_area.is_empty():
		return
	save_game("auto")


func load_game(filename: String = "") -> bool:
	if filename.is_empty():
		var saves = get_all_saves()
		if saves.is_empty():
			return false
		filename = saves[0].get("filename", "")
	
	var payload := _read_payload(filename)
	if payload.is_empty():
		load_completed.emit(filename, false)
		return false
		
	var global_data = payload.get("global_game_state")
	var scene_data = payload.get("scene_game_state")
	if not global_data is Dictionary or not scene_data is Dictionary:
		push_error("Save file %s is missing required state sections." % filename)
		load_completed.emit(filename, false)
		return false
		
	_loading = true
	var success: bool = _game_state != null and _game_state.load_save_data(global_data, scene_data)
	_loading = false
	
	if success:
		_active_filename = filename
	load_completed.emit(filename, success)
	return success


func delete_save(filename: String) -> bool:
	var save_path := _save_path(filename)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		return true
	return false


func get_all_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(SAVE_DIRECTORY):
		return saves
		
	var dir = DirAccess.open(SAVE_DIRECTORY)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".save") and not dir.current_is_dir():
				var payload = _read_payload(file_name)
				if not payload.is_empty() and payload.has("metadata"):
					var metadata = payload.get("metadata", {}).duplicate(true)
					metadata["filename"] = file_name
					saves.append(metadata)
			file_name = dir.get_next()
			
	saves.sort_custom(func(a, b): return a.get("saved_at_unix", 0) > b.get("saved_at_unix", 0))
	return saves


func _get_filename_for_save(type: String, _save_name: String) -> String:
	if type == "quick":
		return "quicksave.save"
	var timestamp = int(Time.get_unix_time_from_system())
	if type == "auto":
		return "autosave_%d.save" % timestamp
	return "manual_%d.save" % timestamp


func _write_payload(filename: String, payload: Dictionary) -> bool:
	var payload_bytes := var_to_bytes(payload)
	var file := FileAccess.open(_save_path(filename), FileAccess.WRITE)
	if file == null:
		push_error("Unable to open save file for writing: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_buffer(payload_bytes)
	file.close()
	return true


func _read_payload(filename: String) -> Dictionary:
	var file := FileAccess.open(_save_path(filename), FileAccess.READ)
	if file == null:
		return {}
	var payload_bytes := file.get_buffer(file.get_length())
	var decoded = bytes_to_var(payload_bytes)
	if not decoded is Dictionary:
		return {}
	return decoded


func _save_path(filename: String) -> String:
	return "%s/%s" % [SAVE_DIRECTORY, filename]
