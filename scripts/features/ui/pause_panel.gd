## Pause menu surface that forwards button presses as semantic signals.
class_name PausePanelSurface
extends PanelContainer

signal resume_pressed
signal quit_to_menu_pressed
signal quit_game_pressed


func _on_resume_pressed() -> void:
	resume_pressed.emit()


func _on_quit_to_menu_pressed() -> void:
	quit_to_menu_pressed.emit()


func _on_quit_game_pressed() -> void:
	quit_game_pressed.emit()
