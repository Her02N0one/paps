@tool
## Intro surface that emits a single continue action into UI orchestration.
class_name IntroPanelSurface
extends GamePanel



func _init() -> void:
	modal_id = &"intro"
	pauses_game = true

func _on_continue_pressed() -> void:
	close_panel()
