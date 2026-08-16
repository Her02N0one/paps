extends SceneTree

const SLOT := 0
const TARGET_AREA := "res://shared/sandbox/gym.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := GameState.new()
	root.add_child(game_state)
	await process_frame

	var save_manager := SaveManager.new()
	root.add_child(save_manager)
	save_manager.configure(game_state, game_state.get_inventory())
	await process_frame

	if not _write_legacy_v0_save(save_manager):
		push_error("Migration test setup failed: could not write legacy payload.")
		quit(1)
		return

	var loaded := save_manager.load_game("")
	var migrated_flag: bool = bool(game_state.get_global_flag(&"legacy_flag", false))
	var migrated_area: bool = game_state.current_area == TARGET_AREA

	if not loaded or not migrated_flag or not migrated_area:
		push_error("SaveManager migration regression detected.")
		quit(1)
		return

	quit()


func _write_legacy_v0_save(save_manager: SaveManager) -> bool:
	var save_path := ProjectSettings.globalize_path("user://saves/slot_%d.save" % SLOT)
	var backup_path := save_path + ".backup"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)

	var payload := {
		"metadata": {
			"format_version": 0,
			"saved_at_unix": int(Time.get_unix_time_from_system()),
			"saved_at_utc": Time.get_datetime_string_from_system(true),
			"application_version": "legacy",
			"slot": SLOT,
		},
		"global_state": {
			"current_area": TARGET_AREA,
			"globals": {"legacy_flag": true},
			"inventory": [],
		},
		"scene_state": {},
	}
	var payload_bytes := var_to_bytes(payload)
	var checksum := save_manager._checksum(payload_bytes)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_32(SaveManager.FILE_MAGIC)
	file.store_32(SaveManager.SAVE_FORMAT_VERSION)
	file.store_32(payload_bytes.size())
	file.store_buffer(checksum)
	file.store_buffer(payload_bytes)
	var write_error := file.get_error()
	file.close()
	return write_error == OK
