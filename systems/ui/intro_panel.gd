@tool
## Intro surface that emits a single continue action into UI orchestration.
class_name IntroPanelSurface
extends GamePanel

signal continue_pressed

func _init() -> void:
	modal_id = &"intro"
	pauses_game = true

func _on_continue_pressed() -> void:
	continue_pressed.emit()
