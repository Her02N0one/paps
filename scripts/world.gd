extends Node3D


@onready var game_ui: Control = $CanvasLayer/GameUI
@onready var intro_panel: Control = $CanvasLayer/GameUI/IntroPanel
@onready var pause_panel: Control = $CanvasLayer/GameUI/PausePanel

var can_pause := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	intro_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	intro_panel.visible = true
	pause_panel.visible = false
	can_pause = false


func _unhandled_input(event: InputEvent) -> void:
	if not can_pause:
		return

	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			_resume_game()
		else:
			_open_pause_menu()


func _on_intro_continue_pressed() -> void:
	intro_panel.visible = false
	can_pause = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	_resume_game()


func _on_quit_to_menu_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_quit_game_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()


func _open_pause_menu() -> void:
	pause_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume_game() -> void:
	pause_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED