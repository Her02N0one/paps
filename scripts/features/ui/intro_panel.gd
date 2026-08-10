## Intro surface that emits a single continue action into UI orchestration.
class_name IntroPanelSurface
extends PanelContainer

signal continue_pressed


func _on_continue_pressed() -> void:
	continue_pressed.emit()
