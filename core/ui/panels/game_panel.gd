## Base contract for every interactive modal panel managed by GameUIController.
## Extend this and set modal_id in the Inspector — the panel self-registers with
## the coordinator at runtime. No scene array or NodePath wiring required.
##
## Editing workflow: tick "Editor Preview" in the Inspector to show the panel
## while designing it. The game always hides panels on startup regardless of
## how the scene was saved.
@tool
class_name GamePanel
extends PanelContainer

@warning_ignore("unused_signal")
signal opened
@warning_ignore("unused_signal")
signal closed

@export var modal_id: StringName
@export var pauses_game: bool = false

@export_group("Editor Tools")
@export var editor_preview: bool = false:
	set(v):
		editor_preview = v
		if Engine.is_editor_hint():
			visible = v


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Always start hidden regardless of saved visible state.
	visible = false
	# Removed manual registration, handled by GameUIController


func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
