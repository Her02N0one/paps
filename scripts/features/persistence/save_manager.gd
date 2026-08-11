## Owns save-slot IO, schema migration, and autosave coalescing.
class_name SaveManager
extends Node

signal save_completed(slot: int, success: bool)
signal load_completed(slot: int, success: bool)

const SAVE_FORMAT_VERSION := 1
const OLDEST_SUPPORTED_FORMAT_VERSION := 0
const DEFAULT_SLOT := 0
const SAVE_DIRECTORY := "user://saves"
const FILE_MAGIC := 0x50415053
const CHECKSUM_SIZE := 32
const HEADER_SIZE := 12 + CHECKSUM_SIZE
const MAX_PAYLOAD_SIZE := 64 * 1024 * 1024

var _active_slot := DEFAULT_SLOT
var _loading := false
var _save_queued := false
var _game_state: GameState
var _inventory: InventoryStore


func _ready() -> void:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))
	# Save system cannot operate without a writable directory.
	if error != OK:
		push_error("Unable to create save directory: %s" % error_string(error))


func configure(game_state: GameState, inventory: InventoryStore) -> void:
	# Reconfigure safely by disconnecting prior signal sources before rebinding.
	# Prior game_state may still be alive when reloading contexts.
	if _game_state and _game_state.state_changed.is_connected(_queue_autosave):
		_game_state.state_changed.disconnect(_queue_autosave)
	# Same for inventory signal, otherwise autosave can trigger multiple times.
	if _inventory and _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.disconnect(_on_inventory_changed)
	_game_state = game_state
	_inventory = inventory
	# Rebind only when dependencies are present.
	if _game_state:
		_game_state.state_changed.connect(_queue_autosave)
	if _inventory:
		_inventory.changed.connect(_on_inventory_changed)


func start_new_game(initial_area: String, slot: int = DEFAULT_SLOT) -> bool:
	# GameState is required to initialize a new runtime profile.
	if _game_state == null:
		return false
	_active_slot = slot
	_loading = true
	_game_state.reset(initial_area)
	_loading = false
	return save_game(slot)


func has_save(slot: int = DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(_save_path(slot)) or FileAccess.file_exists(_backup_path(slot))


func save_game(slot: int = _active_slot) -> bool:
	_save_queued = false
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("capture_player_transform_for_save"):
		world.call("capture_player_transform_for_save")
	# Current area is the minimum viable runtime marker for a resumable save.
	if _game_state == null or _game_state.current_area.is_empty():
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
		"global_game_state": _game_state.to_global_save_data(),
		"scene_game_state": _game_state.to_scene_save_data(),
	}
	var success := _write_payload(slot, payload)
	# Active slot only advances after successful write/replace.
	if success:
		_active_slot = slot
	save_completed.emit(slot, success)
	return success


func load_game(slot: int = DEFAULT_SLOT) -> bool:
	var payload := _read_payload(slot)
	# Empty payload means both primary and backup failed validation.
	if payload.is_empty():
		load_completed.emit(slot, false)
		return false
	var global_data = payload.get("global_game_state")
	var scene_data = payload.get("scene_game_state")
	# Require both state sections before attempting runtime load.
	if not global_data is Dictionary or not scene_data is Dictionary:
		push_error("Save slot %d is missing required state sections." % slot)
		load_completed.emit(slot, false)
		return false
	_loading = true
	var success: bool = _game_state != null and _game_state.load_save_data(global_data, scene_data)
	_loading = false
	# Promote slot only when runtime accepted the payload.
	if success:
		_active_slot = slot
	load_completed.emit(slot, success)
	return success


func get_metadata(slot: int = DEFAULT_SLOT) -> Dictionary:
	var payload := _read_payload(slot)
	var metadata = payload.get("metadata", {})
	# Duplicate protects callers from mutating canonical cached payload data.
	return metadata.duplicate(true) if metadata is Dictionary else {}


func _write_payload(slot: int, payload: Dictionary) -> bool:
	var payload_bytes := var_to_bytes(payload)
	# Reject empty or oversized payloads before touching disk.
	if payload_bytes.is_empty() or payload_bytes.size() > MAX_PAYLOAD_SIZE:
		push_error("Save payload size is invalid: %d bytes." % payload_bytes.size())
		return false
	# Write completely to a temporary file before replacing the live save; a crash cannot leave a half-written slot.
	var temp_path := _temp_path(slot)
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
		push_error("Unable to write save slot %d: %s" % [slot, error_string(write_error)])
		return false
	return _replace_save_file(slot)


func _read_payload(slot: int) -> Dictionary:
	# Prefer primary slot, then fallback to backup and restore it if valid.
	var payload := _read_payload_file(_save_path(slot), slot)
	# Primary save is valid; no backup read needed.
	if not payload.is_empty():
		return payload
	# No backup means there is no recovery path for this slot.
	if not FileAccess.file_exists(_backup_path(slot)):
		return {}
	var backup_payload := _read_payload_file(_backup_path(slot), slot)
	# Backup existed but failed validation.
	if backup_payload.is_empty():
		return {}
	push_warning("Recovered save slot %d from its backup." % slot)
	_restore_backup(slot)
	return backup_payload


func _read_payload_file(path: String, slot: int) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	# Missing/unreadable file is handled by caller fallback chain.
	if file == null:
		return {}
	# Truncated files cannot even contain header metadata.
	if file.get_length() < HEADER_SIZE:
		push_error("Save slot %d is truncated." % slot)
		return {}
	var magic := file.get_32()
	var version := file.get_32()
	var payload_size := file.get_32()
	# Header and size checks fail fast before allocating/decoding arbitrary payload bytes.
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
	# Payload must deserialize into expected dictionary structure.
	if not decoded is Dictionary:
		push_error("Save slot %d contains invalid data." % slot)
		return {}
	var metadata = decoded.get("metadata")
	# Metadata drives migration/version validation and is mandatory.
	if not metadata is Dictionary:
		push_error("Save slot %d metadata is invalid." % slot)
		return {}
	var payload_version := int(metadata.get("format_version", -1))
	# Reject payloads we cannot migrate safely.
	if payload_version < OLDEST_SUPPORTED_FORMAT_VERSION or payload_version > SAVE_FORMAT_VERSION:
		push_error("Save slot %d uses unsupported payload schema version %d." % [slot, payload_version])
		return {}
	var migrated := _migrate_payload(decoded, payload_version)
	# Migration failure means caller should try backup or fail load.
	if migrated.is_empty():
		push_error("Save slot %d could not be migrated to schema version %d." % [slot, SAVE_FORMAT_VERSION])
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


func _replace_save_file(slot: int) -> bool:
	# Keep the previous valid save as a backup until the temporary file becomes the new live save.
	var save_path := ProjectSettings.globalize_path(_save_path(slot))
	var temp_path := ProjectSettings.globalize_path(_temp_path(slot))
	var backup_path := ProjectSettings.globalize_path(_backup_path(slot))
	# Remove stale backup first so rename cannot fail from destination collision.
	if FileAccess.file_exists(_backup_path(slot)):
		DirAccess.remove_absolute(backup_path)
	# Rotate current live save into backup before promoting the temporary file.
	if FileAccess.file_exists(_save_path(slot)):
		var backup_error := DirAccess.rename_absolute(save_path, backup_path)
		if backup_error != OK:
			push_error("Unable to preserve save slot %d: %s" % [slot, error_string(backup_error)])
			return false
	var replace_error := DirAccess.rename_absolute(temp_path, save_path)
	# On replace failure, try to roll backup back into place.
	if replace_error != OK:
		push_error("Unable to finalize save slot %d: %s" % [slot, error_string(replace_error)])
		if FileAccess.file_exists(_backup_path(slot)):
			DirAccess.rename_absolute(backup_path, save_path)
		return false
	return true


func _restore_backup(slot: int) -> void:
	var save_path := ProjectSettings.globalize_path(_save_path(slot))
	var backup_path := ProjectSettings.globalize_path(_backup_path(slot))
	# Drop broken primary before restoring backup into canonical save path.
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
	# Skip autosave while loading, without state, without area, or when already queued.
	if _loading or _game_state == null or _game_state.current_area.is_empty() or _save_queued:
		return
	_save_queued = true
	# Deferring coalesces several state_changed signals from one gameplay action into a single disk write.
	_autosave.call_deferred()


func _on_inventory_changed(_slots: Array[InventorySlot]) -> void:
	_queue_autosave()


func _autosave() -> void:
	# Deferred call may run after queue was canceled by explicit save.
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
