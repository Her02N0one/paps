extends Node

signal save_completed(slot: int, success: bool)
signal load_completed(slot: int, success: bool)

const SAVE_FORMAT_VERSION := 1
const DEFAULT_SLOT := 0
const SAVE_DIRECTORY := "user://saves"
const FILE_MAGIC := 0x50415053
const CHECKSUM_SIZE := 32
const HEADER_SIZE := 12 + CHECKSUM_SIZE
const MAX_PAYLOAD_SIZE := 64 * 1024 * 1024

var _active_slot := DEFAULT_SLOT
var _loading := false
var _save_queued := false


func _ready() -> void:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))
	if error != OK:
		push_error("Unable to create save directory: %s" % error_string(error))
	GameState.state_changed.connect(_queue_autosave)
	Inventory.changed.connect(_on_inventory_changed)


func start_new_game(initial_area: String, slot: int = DEFAULT_SLOT) -> bool:
	_active_slot = slot
	_loading = true
	GameState.reset(initial_area)
	_loading = false
	return save_game(slot)


func has_save(slot: int = DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(_save_path(slot)) or FileAccess.file_exists(_backup_path(slot))


func save_game(slot: int = _active_slot) -> bool:
	_save_queued = false
	if GameState.current_area.is_empty():
		save_completed.emit(slot, false)
		return false
	var payload := {
		"metadata": {
			"format_version": SAVE_FORMAT_VERSION,
			"saved_at_unix": int(Time.get_unix_time_from_system()),
			"saved_at_utc": Time.get_datetime_string_from_system(true),
			"application_version": str(ProjectSettings.get_setting("application/config/version", "development")),
			"slot": slot,
		},
		"global_game_state": GameState.to_global_save_data(),
		"scene_game_state": GameState.to_scene_save_data(),
	}
	var success := _write_payload(slot, payload)
	if success:
		_active_slot = slot
	save_completed.emit(slot, success)
	return success


func load_game(slot: int = DEFAULT_SLOT) -> bool:
	var payload := _read_payload(slot)
	if payload.is_empty():
		load_completed.emit(slot, false)
		return false
	var global_data = payload.get("global_game_state")
	var scene_data = payload.get("scene_game_state")
	if not global_data is Dictionary or not scene_data is Dictionary:
		push_error("Save slot %d is missing required state sections." % slot)
		load_completed.emit(slot, false)
		return false
	_loading = true
	var success := GameState.load_save_data(global_data, scene_data)
	_loading = false
	if success:
		_active_slot = slot
	load_completed.emit(slot, success)
	return success


func get_metadata(slot: int = DEFAULT_SLOT) -> Dictionary:
	var payload := _read_payload(slot)
	var metadata = payload.get("metadata", {})
	return metadata.duplicate(true) if metadata is Dictionary else {}


func _write_payload(slot: int, payload: Dictionary) -> bool:
	var payload_bytes := var_to_bytes(payload)
	if payload_bytes.is_empty() or payload_bytes.size() > MAX_PAYLOAD_SIZE:
		push_error("Save payload size is invalid: %d bytes." % payload_bytes.size())
		return false
	var temp_path := _temp_path(slot)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
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
	if write_error != OK:
		push_error("Unable to write save slot %d: %s" % [slot, error_string(write_error)])
		return false
	return _replace_save_file(slot)


func _read_payload(slot: int) -> Dictionary:
	var payload := _read_payload_file(_save_path(slot), slot)
	if not payload.is_empty():
		return payload
	if not FileAccess.file_exists(_backup_path(slot)):
		return {}
	var backup_payload := _read_payload_file(_backup_path(slot), slot)
	if backup_payload.is_empty():
		return {}
	push_warning("Recovered save slot %d from its backup." % slot)
	_restore_backup(slot)
	return backup_payload


func _read_payload_file(path: String, slot: int) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() < HEADER_SIZE:
		push_error("Save slot %d is truncated." % slot)
		return {}
	var magic := file.get_32()
	var version := file.get_32()
	var payload_size := file.get_32()
	if magic != FILE_MAGIC or version != SAVE_FORMAT_VERSION:
		push_error("Save slot %d has an invalid header or unsupported version." % slot)
		return {}
	if payload_size <= 0 or payload_size > MAX_PAYLOAD_SIZE or file.get_length() != HEADER_SIZE + payload_size:
		push_error("Save slot %d has an invalid payload length." % slot)
		return {}
	var stored_checksum := file.get_buffer(CHECKSUM_SIZE)
	var payload_bytes := file.get_buffer(payload_size)
	if file.get_error() != OK or payload_bytes.size() != payload_size:
		push_error("Save slot %d could not be read completely." % slot)
		return {}
	if stored_checksum != _checksum(payload_bytes):
		push_error("Save slot %d failed its integrity check." % slot)
		return {}
	var decoded = bytes_to_var(payload_bytes)
	if not decoded is Dictionary:
		push_error("Save slot %d contains invalid data." % slot)
		return {}
	var metadata = decoded.get("metadata")
	if not metadata is Dictionary or int(metadata.get("format_version", 0)) != SAVE_FORMAT_VERSION:
		push_error("Save slot %d metadata is invalid." % slot)
		return {}
	return decoded


func _replace_save_file(slot: int) -> bool:
	var save_path := ProjectSettings.globalize_path(_save_path(slot))
	var temp_path := ProjectSettings.globalize_path(_temp_path(slot))
	var backup_path := ProjectSettings.globalize_path(_backup_path(slot))
	if FileAccess.file_exists(_backup_path(slot)):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(_save_path(slot)):
		var backup_error := DirAccess.rename_absolute(save_path, backup_path)
		if backup_error != OK:
			push_error("Unable to preserve save slot %d: %s" % [slot, error_string(backup_error)])
			return false
	var replace_error := DirAccess.rename_absolute(temp_path, save_path)
	if replace_error != OK:
		push_error("Unable to finalize save slot %d: %s" % [slot, error_string(replace_error)])
		if FileAccess.file_exists(_backup_path(slot)):
			DirAccess.rename_absolute(backup_path, save_path)
		return false
	return true


func _restore_backup(slot: int) -> void:
	var save_path := ProjectSettings.globalize_path(_save_path(slot))
	var backup_path := ProjectSettings.globalize_path(_backup_path(slot))
	if FileAccess.file_exists(_save_path(slot)):
		DirAccess.remove_absolute(save_path)
	var error := DirAccess.rename_absolute(backup_path, save_path)
	if error != OK:
		push_error("Unable to restore backup for save slot %d: %s" % [slot, error_string(error)])


func _checksum(data: PackedByteArray) -> PackedByteArray:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(data)
	return hashing.finish()


func _queue_autosave() -> void:
	if _loading or GameState.current_area.is_empty() or _save_queued:
		return
	_save_queued = true
	_autosave.call_deferred()


func _on_inventory_changed(_slots: Array[InventorySlot]) -> void:
	_queue_autosave()


func _autosave() -> void:
	if not _save_queued:
		return
	_save_queued = false
	save_game(_active_slot)


func _save_path(slot: int) -> String:
	return "%s/slot_%d.save" % [SAVE_DIRECTORY, slot]


func _temp_path(slot: int) -> String:
	return _save_path(slot) + ".tmp"


func _backup_path(slot: int) -> String:
	return _save_path(slot) + ".backup"
