extends Node


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var continue_button: Button = $MainMenu/MainMenuGUI/HBoxContainer/VBoxContainer/MenuOptions/Continue
	var options_button: Button = $MainMenu/MainMenuGUI/HBoxContainer/VBoxContainer/MenuOptions/Options
	continue_button.disabled = not SaveManager.has_save()
	options_button.disabled = true
	GameManager.fade_in()


func _on_new_game_pressed() -> void:
	GameManager.start_new_game("res://scenes/playground.tscn")


func _on_continue_pressed() -> void:
	if SaveManager.load_game():
		GameManager.continue_game()
