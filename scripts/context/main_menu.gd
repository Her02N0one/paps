@tool
## Main-menu context surface that binds services and forwards player choices.
class_name MainMenuContext
extends Node

@export_file("*.tscn") var new_game_start_scene := "res://scenes/levels/playground.tscn"
@export var new_game_spawn_marker_id: StringName

var _game_manager: GameManager
var _save_manager: SaveManager
var _continue_button: Button
var _new_game_button: Button
var _options_button: Button


func bind_services(game_manager: GameManager, save_manager: SaveManager) -> void:
	_game_manager = game_manager
	_save_manager = save_manager


func _ready() -> void:
	# In editor mode we only validate scene wiring and skip runtime side effects.
	if Engine.is_editor_hint():
		update_configuration_warnings()
		return
	# Runtime depends on both services being bound by RootContext before this node enters tree.
	if _game_manager == null or _save_manager == null:
		push_error("MainMenu services are not bound. Call bind_services() before adding MainMenu to the tree.")
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_continue_button = get_node_or_null("%Continue") as Button
	_new_game_button = get_node_or_null("%NewGame") as Button
	_options_button = get_node_or_null("%Options") as Button
	# Abort setup if any required action button is missing from the scene contract.
	if _continue_button == null or _new_game_button == null or _options_button == null:
		push_error("Main menu buttons are missing. Ensure Continue/NewGame/Options are unique-name nodes.")
		return
	# Connect once so re-entering the scene does not duplicate signal callbacks.
	if not _new_game_button.pressed.is_connected(_on_new_game_pressed):
		_new_game_button.pressed.connect(_on_new_game_pressed)
	# Continue uses the same idempotent signal wiring pattern as New Game.
	if not _continue_button.pressed.is_connected(_on_continue_pressed):
		_continue_button.pressed.connect(_on_continue_pressed)
	# Continue only becomes available when a persisted slot exists.
	_continue_button.disabled = not _save_manager.has_save()
	_options_button.disabled = true
	_game_manager.fade_in()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	# Mirror runtime button requirements so missing nodes are visible in the editor.
	if get_node_or_null("%Continue") == null:
		warnings.append("MainMenuContext requires a unique-name Continue button.")
	if get_node_or_null("%NewGame") == null:
		warnings.append("MainMenuContext requires a unique-name NewGame button.")
	if get_node_or_null("%Options") == null:
		warnings.append("MainMenuContext requires a unique-name Options button.")
	if new_game_start_scene.is_empty():
		warnings.append("new_game_start_scene is empty; New Game will not start gameplay.")
	elif not ResourceLoader.exists(new_game_start_scene, "PackedScene"):
		warnings.append("new_game_start_scene does not resolve to an existing PackedScene: %s" % new_game_start_scene)
	return warnings


func _on_new_game_pressed() -> void:
	# Guard against broken scene configuration before forwarding the request.
	if new_game_start_scene.is_empty() or not ResourceLoader.exists(new_game_start_scene, "PackedScene"):
		push_error("Cannot start a new game: new_game_start_scene is invalid.")
		return
	_game_manager.start_new_game(new_game_start_scene, new_game_spawn_marker_id)


func _on_continue_pressed() -> void:
	# Continue only transitions after a save payload has been loaded into runtime state.
	if _save_manager.load_game():
		_game_manager.continue_game()
