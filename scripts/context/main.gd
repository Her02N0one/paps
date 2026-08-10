## Legacy main-menu script retained for migration compatibility with older scene wiring.
class_name MainMenu
extends Node

var _game_manager: GameManager
var _save_manager: SaveManager
var _continue_button: Button
var _new_game_button: Button
var _options_button: Button


func bind_services(game_manager: GameManager, save_manager: SaveManager) -> void:
	_game_manager = game_manager
	_save_manager = save_manager


func _ready() -> void:
	if _game_manager == null or _save_manager == null:
		push_error("MainMenu services are not bound. Call bind_services() before adding MainMenu to the tree.")
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_continue_button = get_node_or_null("MainMenu/MainMenuGUI/HBoxContainer/VBoxContainer/MenuOptions/Continue") as Button
	_new_game_button = get_node_or_null("MainMenu/MainMenuGUI/HBoxContainer/VBoxContainer/MenuOptions/NewGame") as Button
	_options_button = get_node_or_null("MainMenu/MainMenuGUI/HBoxContainer/VBoxContainer/MenuOptions/Options") as Button
	# This legacy script still relies on deep explicit paths rather than unique-name lookups.
	if _continue_button == null or _new_game_button == null or _options_button == null:
		push_error("Main menu buttons are missing from Main scene.")
		return
	if not _new_game_button.pressed.is_connected(_on_new_game_pressed):
		_new_game_button.pressed.connect(_on_new_game_pressed)
	if not _continue_button.pressed.is_connected(_on_continue_pressed):
		_continue_button.pressed.connect(_on_continue_pressed)
	_continue_button.disabled = not _save_manager.has_save()
	_options_button.disabled = true
	_game_manager.fade_in()


func _on_new_game_pressed() -> void:
	_game_manager.start_new_game("res://scenes/levels/playground.tscn")


func _on_continue_pressed() -> void:
	if _save_manager.load_game():
		_game_manager.continue_game()
