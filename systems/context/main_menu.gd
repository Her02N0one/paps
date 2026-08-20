@tool
## Main-menu context surface that binds services and forwards player choices.
class_name MainMenuContext
extends Node

@export_file("*.tscn") var new_game_start_scene := "res://scenes/maps/playground.tscn"
@export var new_game_spawn_marker_id: StringName

var _game_manager: GameManager
var _save_manager
var _continue_button: Button
var _load_game_button: Button
var _new_game_button: Button
var _options_button: Button
var _nose_button: Button
var _squak_noise: AudioStreamPlayer


func bind_services(game_manager: GameManager, save_manager) -> void:
	_game_manager = game_manager
	_save_manager = save_manager


func _ready() -> void:
	# In editor mode we only validate scene wiring and skip runtime side effects.
	if Engine.is_editor_hint():
		update_configuration_warnings()
		return
	_nose_button = get_node("MainMenu/Button") as Button
	_squak_noise = get_node("MainMenu/Button/SquakNoise") as AudioStreamPlayer
	var bg_texture := get_node("MainMenu/TextureRect") as Control
	var menu_gui := get_node("MainMenu/MainMenuGUI") as Control
	if bg_texture != null:
		bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if menu_gui != null:
		menu_gui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _nose_button != null and not _nose_button.pressed.is_connected(_on_button_pressed):
		_nose_button.pressed.connect(_on_button_pressed)
	# Runtime depends on both services being bound by RootContext before this node enters tree.
	if _game_manager == null or _save_manager == null:
		push_error("MainMenu services are not bound. Call bind_services() before adding MainMenu to the tree.")
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_continue_button = get_node("%Continue") as Button
	_load_game_button = get_node("%LoadGame") as Button
	_new_game_button = get_node("%NewGame") as Button
	_options_button = get_node("%Options") as Button
	# Abort setup if any required action button is missing from the scene contract.
	assert(_continue_button != null and _new_game_button != null and _options_button != null and _load_game_button != null, "Main menu buttons are missing. Ensure Continue/LoadGame/NewGame/Options are unique-name nodes.")
	# Connect once so re-entering the scene does not duplicate signal callbacks.
	if not _new_game_button.pressed.is_connected(_on_new_game_pressed):
		_new_game_button.pressed.connect(_on_new_game_pressed)
	# Continue uses the same idempotent signal wiring pattern as New Game.
	if not _continue_button.pressed.is_connected(_on_continue_pressed):
		_continue_button.pressed.connect(_on_continue_pressed)
	if not _load_game_button.pressed.is_connected(_on_load_game_pressed):
		_load_game_button.pressed.connect(_on_load_game_pressed)
		
	# Continue and Load Game only become available when a persisted slot exists.
	var has_save = _save_manager.has_save()
	_continue_button.disabled = not has_save
	_load_game_button.disabled = not has_save
	_options_button.disabled = true
	_game_manager.fade_in()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	# Mirror runtime button requirements so missing nodes are visible in the editor.
	if get_node_or_null("%Continue") == null:
		warnings.append("MainMenuContext requires a unique-name Continue button.")
	if get_node_or_null("%LoadGame") == null:
		warnings.append("MainMenuContext requires a unique-name LoadGame button.")
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
	if _save_manager.load_game(""):
		_game_manager.continue_game()


func _on_load_game_pressed() -> void:
	var load_menu = get_node("MainMenu/LoadMenuPanel") as GamePanel
	load_menu.open_panel()


func _on_button_pressed() -> void:
	_play_squak_noise()


func _play_squak_noise() -> void:
	_squak_noise.stop()
	_squak_noise.seek(0.0)
	_squak_noise.play()
