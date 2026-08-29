## Canonical mutable game-state store shared by runtime systems and persistence.
class_name GameState
extends Node

# ==============================================================================
# Signals
# ==============================================================================
signal state_changed
signal person_record_changed(person_id: StringName, record: Dictionary)

# ==============================================================================
# Constants
# ==============================================================================
## v2 adds top-level disposition/current_health (mirrored from profile) and natural_expiry_unix.
const PERSON_RECORD_VERSION := 2

# ==============================================================================
# Public Variables
# ==============================================================================
var current_area := ""
var player_transform := Transform3D(Basis.IDENTITY, Vector3.ZERO)
var current_day: int = 1
var current_time_minutes: float = 480.0
var global_flags: Dictionary = {}

# ==============================================================================
# Private Variables
# ==============================================================================
var _areas: Dictionary = {}
var _inventory: InventoryStore = InventoryStore.new()

# ==============================================================================
# Lifecycle Methods
# ==============================================================================
func _ready() -> void:
	add_child(_inventory)
	add_to_group("game_state")

# ==============================================================================
# Public Methods - General
# ==============================================================================
func get_inventory() -> InventoryStore:
	return _inventory

func get_in_game_time_string() -> String:
	@warning_ignore("integer_division")
	var hours := int(current_time_minutes) / 60
	var minutes := int(current_time_minutes) % 60
	return "DAY %d, %02d:%02d" % [current_day, hours, minutes]

func reset(initial_area: String) -> void:
	current_area = initial_area
	player_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	current_day = 1
	current_time_minutes = 480.0
	global_flags.clear()
	_areas.clear()
	if _inventory:
		_inventory.clear()
	state_changed.emit()

# ==============================================================================
# Public Methods - Serialization
# ==============================================================================
func to_global_save_data() -> Dictionary:
	return {
		"current_area": current_area,
		"player_transform": player_transform,
		"current_day": current_day,
		"current_time_minutes": current_time_minutes,
		"flags": global_flags.duplicate(true),
		"inventory": _inventory.to_save_data() if _inventory else [],
	}

func to_scene_save_data() -> Dictionary:
	return _areas.duplicate(true)

func load_save_data(global_data: Dictionary, scene_data: Dictionary) -> bool:
	var area_path := str(global_data.get("current_area", ""))
	var saved_player_transform = global_data.get("player_transform", Transform3D(Basis.IDENTITY, Vector3.ZERO))
	var inventory_data = global_data.get("inventory", [])
	var flags = global_data.get("flags", {})
	
	if area_path.is_empty() or not inventory_data is Array or not flags is Dictionary:
		return false
		
	current_area = area_path
	player_transform = saved_player_transform if typeof(saved_player_transform) == TYPE_TRANSFORM3D else Transform3D(Basis.IDENTITY, Vector3.ZERO)
	current_day = int(global_data.get("current_day", 1))
	current_time_minutes = float(global_data.get("current_time_minutes", 480.0))
	global_flags = flags.duplicate(true)
	
	_areas = scene_data.duplicate(true)
	
	if _inventory:
		_inventory.load_save_data(inventory_data)
	state_changed.emit()
	return true

# ==============================================================================
# Public Methods - Global Flags & Player
# ==============================================================================
func set_global_flag(flag: StringName, value: Variant) -> void:
	if global_flags.get(flag) == value:
		return
	global_flags[flag] = value
	state_changed.emit()

func get_global_flag(flag: StringName, default_value: Variant = null) -> Variant:
	return global_flags.get(flag, default_value)

func set_player_transform(transform: Transform3D) -> void:
	player_transform = transform

func get_player_transform() -> Transform3D:
	return player_transform

# ==============================================================================
# Private Methods
# ==============================================================================
func _ensure_area(area_path: String) -> Dictionary:
	if not _areas.has(area_path):
		_areas[area_path] = {
			"removed_static_pickups": [],
			"dynamic_pickups": {},
			"components": {}
		}
	return _areas[area_path]
