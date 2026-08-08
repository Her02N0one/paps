extends Node


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var continue_button: Button = $MainMenu/HBoxContainer/VBoxContainer/MenuOptions/Continue
	var options_button: Button = $MainMenu/HBoxContainer/VBoxContainer/MenuOptions/Options
	continue_button.disabled = true
	options_button.disabled = true


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://world.tscn")
