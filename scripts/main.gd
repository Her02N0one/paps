extends Node


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var continue_button: Button = $MainMenu/HBoxContainer/VBoxContainer/MenuOptions/Continue
	var options_button: Button = $MainMenu/HBoxContainer/VBoxContainer/MenuOptions/Options
	continue_button.disabled = true
	options_button.disabled = true
	GameManager.fade_in()


func _on_new_game_pressed() -> void:
	GameManager.start_game("res://scenes/playground.tscn")
