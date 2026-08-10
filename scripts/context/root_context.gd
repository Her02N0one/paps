@tool
## Application composition root: owns long-lived services and active context switching.
class_name RootContext
extends Node

signal context_switched(previous_context: StringName, next_context: StringName, context_node: Node)

const CONTEXT_NONE := &""
const CONTEXT_MAIN_MENU := &"main_menu"
const CONTEXT_WORLD := &"world"
const MAIN_MENU_CONTEXT_SCENE_PATH := "res://scenes/main/main_menu.tscn"
const WORLD_SCENE_PATH := "res://scenes/world/world_root.tscn"
const MAIN_MENU_CONTEXT_SCENE := preload(MAIN_MENU_CONTEXT_SCENE_PATH)
const WORLD_SCENE := preload(WORLD_SCENE_PATH)


var game_state: GameState
var save_manager: SaveManager
var game_manager: GameManager
var settings_manager: SettingsManager
var _active_context: Node
var _active_context_id: StringName = CONTEXT_NONE


func _ready() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
		return
	_build_services()
	_bind_services()
	_mount_main_menu_context()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not ResourceLoader.exists(MAIN_MENU_CONTEXT_SCENE_PATH, "PackedScene"):
		warnings.append("RootContext requires a valid main menu context scene at %s." % MAIN_MENU_CONTEXT_SCENE_PATH)
	if not ResourceLoader.exists(WORLD_SCENE_PATH, "PackedScene"):
		warnings.append("RootContext requires a valid world context scene at %s." % WORLD_SCENE_PATH)
	return warnings


func _build_services() -> void:
	game_state = GameState.new()
	game_state.name = "GameState"
	add_child(game_state)
	settings_manager = SettingsManager.new()
	settings_manager.name = "SettingsManager"
	add_child(settings_manager)
	save_manager = SaveManager.new()
	save_manager.name = "SaveManager"
	add_child(save_manager)
	game_manager = GameManager.new()
	game_manager.name = "GameManager"
	game_manager.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(game_manager)


func _bind_services() -> void:
	save_manager.configure(game_state, game_state.get_inventory())
	game_manager.configure(save_manager, game_state)
	# GameManager remains decoupled from scene ownership through injected callbacks.
	game_manager.set_context_switch_callbacks(show_world_context, show_main_menu_context)


func show_world_context(_initial_map: String, _spawn_id: String, _reversed: bool) -> void:
	# Context switches always replace the previous context node entirely.
	_free_active_context()
	var world := WORLD_SCENE.instantiate() as World
	if world == null:
		push_error("Failed to instantiate World scene.")
		return
	world.bind_services(game_manager, game_state, save_manager)
	add_child(world)
	_set_active_context(CONTEXT_WORLD, world)


func switch_to_gameplay(_initial_map: String, _spawn_id: String, _reversed: bool) -> void:
	show_world_context(_initial_map, _spawn_id, _reversed)


func show_main_menu_context() -> void:
	_free_active_context()
	_mount_main_menu_context()


func switch_to_menu() -> void:
	show_main_menu_context()


func _mount_main_menu_context() -> void:
	var menu := MAIN_MENU_CONTEXT_SCENE.instantiate()
	if menu == null:
		push_error("Failed to instantiate MainMenuContext scene.")
		return
	if not menu.has_method("bind_services"):
		# Fail fast when scene contracts drift from expected service API.
		push_error("MainMenuContext scene root is missing bind_services(game_manager, save_manager).")
		return
	menu.call("bind_services", game_manager, save_manager)
	add_child(menu)
	_set_active_context(CONTEXT_MAIN_MENU, menu)


func _free_active_context() -> void:
	if is_instance_valid(_active_context):
		_active_context.queue_free()
	_active_context = null


func get_active_context_id() -> StringName:
	return _active_context_id


func get_active_context_node() -> Node:
	return _active_context


func _set_active_context(context_id: StringName, context_node: Node) -> void:
	var previous_context_id := _active_context_id
	_active_context = context_node
	_active_context_id = context_id
	context_switched.emit(previous_context_id, _active_context_id, _active_context)
