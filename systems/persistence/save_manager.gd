## Owns save-slot IO, schema migration, and autosave coalescing.
class_name SaveManager
extends Node

signal save_completed(filename: String, success: bool)
signal load_completed(filename: String, success: bool)

const SAVE_FORMAT_VERSION := 1
const OLDEST_SUPPORTED_FORMAT_VERSION := 0
const SAVE_DIRECTORY := "user://saves"
const FILE_MAGIC := 0x50415053
const CHECKSUM_SIZE := 32
const HEADER_SIZE := 12 + CHECKSUM_SIZE
const MAX_PAYLOAD_SIZE := 64 * 1024 * 1024

var _active_filename := ""
var _loading := false
var _game_state: GameState
var _inventory: InventoryStore


func _ready() -> void:
	var error := DirAccess.make_dir_recursive_absolute(SAVE_DIRECTORY)
	# Save system cannot operate without a writable directory.
	if error != OK:
		push_error("Unable to create save directory: %s" % error_string(error))


func configure(game_state: GameState, inventory: InventoryStore) -> void:
	_game_state = game_state
	_inventory = inventory


func start_new_game(initial_area: String) -> bool:
	# GameState is required to initialize a new runtime profile.
	if _game_state == null:
		return false
	_active_filename = ""
	_loading = true
	_game_state.reset(initial_area)
	_loading = false
	return true


func has_save() -> bool:
	var saves = get_all_saves()
	return saves.size() > 0


func save_game(type: String, save_name: String = "") -> bool:
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("capture_player_transform_for_save"):
		world.call("capture_player_transform_for_save")
	# Current area is the minimum viable runtime marker for a resumable save.
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
			"format_version": SAVE_FORMAT_VERSION,
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
	# Active slot only advances after successful write/replace.
	if success:
		_active_filename = filename
	save_completed.emit(filename, success)
	return success


func trigger_autosave() -> void:
	if _loading or _game_state == null or _game_state.current_area.is_empty():
		return
	save_game("auto")


func _on_game_state_changed() -> void:
	# Previously autosaved on every state change, removed by user request.
	pass


func load_game(filename: String = "") -> bool:
	if filename.is_empty():
		var saves = get_all_saves()
		if saves.is_empty():
			return false
		filename = saves[0].get("filename", "")
	
	var payload := _read_payload(filename)
	# Empty payload means both primary and backup failed validation.
	if payload.is_empty():
		load_completed.emit(filename, false)
		return false
	var global_data = payload.get("global_game_state")
	var scene_data = payload.get("scene_game_state")
	# Require both state sections before attempting runtime load.
	if not global_data is Dictionary or not scene_data is Dictionary:
		push_error("Save file %s is missing required state sections." % filename)
		load_completed.emit(filename, false)
		return false
	_loading = true
	var success: bool = _game_state != null and _game_state.load_save_data(global_data, scene_data)
	_loading = false
	# Promote slot only when runtime accepted the payload.
	if success:
		_active_filename = filename
	load_completed.emit(filename, success)
	return success


func delete_save(filename: String) -> bool:
	var save_path := _save_path(filename)
	var backup_path := _backup_path(filename)
	var deleted = false
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		deleted = true
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
		deleted = true
	return deleted


func get_all_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(SAVE_DIRECTORY):
		return saves
		
	var dir = DirAccess.open(SAVE_DIRECTORY)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if (file_name.ends_with(".save") or file_name.ends_with(".backup")) and not dir.current_is_dir():
				var metadata = _read_metadata_only(file_name)
				if not metadata.is_empty():
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


func _read_metadata_only(filename: String) -> Dictionary:
	var payload := _read_payload(filename)
	if not payload.is_empty() and payload.has("metadata"):
		return payload.get("metadata", {}).duplicate(true)
	return {}


func _write_payload(filename: String, payload: Dictionary) -> bool:
	var payload_bytes := var_to_bytes(payload)
	# Reject empty or oversized payloads before touching disk.
	if payload_bytes.is_empty() or payload_bytes.size() > MAX_PAYLOAD_SIZE:
		push_error("Save payload size is invalid: %d bytes." % payload_bytes.size())
		return false
	# Write completely to a temporary file before replacing the live save; a crash cannot leave a half-written slot.
	var temp_path := _temp_path(filename)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	# Temp file open failure usually means path/permissions issue.
	if file == null:
		push_error("Unable to open temporary save file: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_32(FILE_MAGIC)
	file.store_32(SAVE_FORMAT_VERSION)
	file.store_32(payload_bytes.size())
	file.store_buffer(_checksum(payload_bytes))
	file.store_buffer(payload_bytes)
	var write_error := file.get_error()
	file.close()
	# Abort replace step when any write call failed.
	if write_error != OK:
		push_error("Unable to write save file %s: %s" % [filename, error_string(write_error)])
		return false
	return _replace_save_file(filename)


func _read_payload(filename: String) -> Dictionary:
	# Prefer primary slot, then fallback to backup and restore it if valid.
	var payload := _read_payload_file(_save_path(filename), filename)
	# Primary save is valid; no backup read needed.
	if not payload.is_empty():
		return payload
	# No backup means there is no recovery path for this slot.
	if not FileAccess.file_exists(_backup_path(filename)):
		return {}
	var backup_payload := _read_payload_file(_backup_path(filename), filename)
	# Backup existed but failed validation.
	if backup_payload.is_empty():
		return {}
	push_warning("Recovered save file %s from its backup." % filename)
	_restore_backup(filename)
	return backup_payload


func _read_payload_file(path: String, filename: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	# Missing/unreadable file is handled by caller fallback chain.
	if file == null:
		return {}
	# Truncated files cannot even contain header metadata.
	if file.get_length() < HEADER_SIZE:
		push_error("Save file %s is truncated." % filename)
		return {}
	var magic := file.get_32()
	var version := file.get_32()
	var payload_size := file.get_32()
	# Header and size checks fail fast before allocating/decoding arbitrary payload bytes.
	if magic != FILE_MAGIC or version != SAVE_FORMAT_VERSION:
		push_error("Save file %s has an invalid header or unsupported version." % filename)
		return {}
	if payload_size <= 0 or payload_size > MAX_PAYLOAD_SIZE or file.get_length() != HEADER_SIZE + payload_size:
		push_error("Save file %s has an invalid payload length." % filename)
		return {}
	var stored_checksum := file.get_buffer(CHECKSUM_SIZE)
	var payload_bytes := file.get_buffer(payload_size)
	if file.get_error() != OK or payload_bytes.size() != payload_size:
		push_error("Save file %s could not be read completely." % filename)
		return {}
	if stored_checksum != _checksum(payload_bytes):
		push_error("Save file %s failed its integrity check." % filename)
		return {}
	var decoded = bytes_to_var(payload_bytes)
	# Payload must deserialize into expected dictionary structure.
	if not decoded is Dictionary:
		push_error("Save file %s contains invalid data." % filename)
		return {}
	var metadata = decoded.get("metadata")
	# Metadata drives migration/version validation and is mandatory.
	if not metadata is Dictionary:
		push_error("Save file %s metadata is invalid." % filename)
		return {}
	var payload_version := int(metadata.get("format_version", -1))
	# Reject payloads we cannot migrate safely.
	if payload_version < OLDEST_SUPPORTED_FORMAT_VERSION or payload_version > SAVE_FORMAT_VERSION:
		push_error("Save file %s uses unsupported payload schema version %d." % [filename, payload_version])
		return {}
	var migrated := _migrate_payload(decoded, payload_version)
	# Migration failure means caller should try backup or fail load.
	if migrated.is_empty():
		push_error("Save file %s could not be migrated to schema version %d." % [filename, SAVE_FORMAT_VERSION])
		return {}
	return migrated


func _migrate_payload(payload: Dictionary, from_version: int) -> Dictionary:
	var working := payload.duplicate(true)
	var cursor := from_version
	# Apply one migration step at a time until the current schema is reached.
	while cursor < SAVE_FORMAT_VERSION:
		# Choose migration step by current schema cursor.
		match cursor:
			0:
				working = _migrate_v0_to_v1(working)
			_:
				push_error("No save migration step defined from version %d." % cursor)
				return {}
		# Each step may fail independently; abort as soon as one does.
		if working.is_empty():
			return {}
		cursor += 1
	var metadata := working.get("metadata", {}) as Dictionary
	metadata["format_version"] = SAVE_FORMAT_VERSION
	working["metadata"] = metadata
	# Final schema normalization enforces required top-level sections.
	if not _normalize_payload_shape(working):
		return {}
	return working


func _migrate_v0_to_v1(payload_v0: Dictionary) -> Dictionary:
	var migrated := payload_v0.duplicate(true)
	# Accept legacy key aliases so old slots migrate without manual user intervention.
	# Support `global_state` -> `global_game_state` rename from older builds.
	if migrated.has("global_state") and not migrated.has("global_game_state"):
		migrated["global_game_state"] = migrated.get("global_state", {}).duplicate(true)
	# Support `scene_state` -> `scene_game_state` rename from older builds.
	if migrated.has("scene_state") and not migrated.has("scene_game_state"):
		migrated["scene_game_state"] = migrated.get("scene_state", {}).duplicate(true)
	var global_state := migrated.get("global_game_state", {}) as Dictionary
	# Ensure mandatory v1 counters/containers exist even if missing in legacy save.
	if not global_state.has("next_dynamic_id"):
		global_state["next_dynamic_id"] = 1
	if not global_state.has("people"):
		global_state["people"] = {}
	# Preserve legacy `globals` data under the canonical `flags` key.
	if not global_state.has("flags") and global_state.has("globals"):
		global_state["flags"] = global_state.get("globals", {})
	migrated["global_game_state"] = global_state
	return migrated


func _normalize_payload_shape(payload: Dictionary) -> bool:
	# Both sections are required for deterministic load behavior.
	if not payload.has("global_game_state") or not payload.get("global_game_state") is Dictionary:
		return false
	if not payload.has("scene_game_state") or not payload.get("scene_game_state") is Dictionary:
		return false
	return true


func _replace_save_file(filename: String) -> bool:
	# Keep the previous valid save as a backup until the temporary file becomes the new live save.
	var save_path := _save_path(filename)
	var temp_path := _temp_path(filename)
	var backup_path := _backup_path(filename)
	# Remove stale backup first so rename cannot fail from destination collision.
	if FileAccess.file_exists(_backup_path(filename)):
		DirAccess.remove_absolute(backup_path)
	# Rotate current live save into backup before promoting the temporary file.
	if FileAccess.file_exists(_save_path(filename)):
		var backup_error := DirAccess.rename_absolute(save_path, backup_path)
		if backup_error != OK:
			push_error("Unable to preserve save file %s: %s" % [filename, error_string(backup_error)])
			return false
	var replace_error := DirAccess.rename_absolute(temp_path, save_path)
	# On replace failure, try to roll backup back into place.
	if replace_error != OK:
		push_error("Unable to finalize save file %s: %s" % [filename, error_string(replace_error)])
		if FileAccess.file_exists(_backup_path(filename)):
			DirAccess.rename_absolute(backup_path, save_path)
		return false
	return true


func _restore_backup(filename: String) -> void:
	var save_path := _save_path(filename)
	var backup_path := _backup_path(filename)
	# Drop broken primary before restoring backup into canonical save path.
	if FileAccess.file_exists(_save_path(filename)):
		DirAccess.remove_absolute(save_path)
	var error := DirAccess.rename_absolute(backup_path, save_path)
	if error != OK:
		push_error("Unable to restore backup for save file %s: %s" % [filename, error_string(error)])


func _checksum(data: PackedByteArray) -> PackedByteArray:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(data)
	return hashing.finish()


func _save_path(filename: String) -> String:
	return "%s/%s" % [SAVE_DIRECTORY, filename]


func _temp_path(filename: String) -> String:
	return _save_path(filename) + ".tmp"


func _backup_path(filename: String) -> String:
	return _save_path(filename) + ".backup"
