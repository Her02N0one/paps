## Lightweight user-settings persistence wrapper over ConfigFile.
class_name SettingsManager
extends Node

signal setting_changed(section: String, key: String, value: Variant)

const SETTINGS_PATH := "user://settings.cfg"

var _config := ConfigFile.new()


func _ready() -> void:
	load_settings()


func load_settings() -> bool:
	var error := _config.load(SETTINGS_PATH)
	if error == ERR_FILE_NOT_FOUND:
		# First run: create a settings file immediately so future writes are deterministic.
		return save_settings()
	if error != OK:
		push_error("Unable to load user settings: %s" % error_string(error))
		return false
	return true


func save_settings() -> bool:
	var error := _config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Unable to save user settings: %s" % error_string(error))
		return false
	return true


func get_value(section: String, key: String, default_value: Variant = null) -> Variant:
	return _config.get_value(section, key, default_value)


func set_value(section: String, key: String, value: Variant) -> bool:
	# Skip disk writes and signals when value is unchanged.
	if _config.get_value(section, key, null) == value:
		return true
	_config.set_value(section, key, value)
	var success := save_settings()
	if success:
		setting_changed.emit(section, key, value)
	return success