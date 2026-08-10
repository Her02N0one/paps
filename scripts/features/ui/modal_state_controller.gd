## Tracks the currently active modal and enforces global input/pause invariants.
class_name ModalStateController
extends Node

const NONE := &""

var active_modal: StringName = NONE
var _panels: Dictionary[StringName, Control] = {}
var _crosshair: Control


func configure(panels: Dictionary[StringName, Control], crosshair: Control) -> void:
	_panels = panels.duplicate()
	_crosshair = crosshair
	_hide_all_panels()


func register_panel(modal: StringName, panel: Control) -> void:
	if modal == NONE or panel == null:
		return
	_panels[modal] = panel
	panel.visible = false


func open(modal: StringName) -> void:
	if modal != NONE and not _panels.has(modal):
		push_warning("Cannot open unregistered modal '%s'." % modal)
		return
	# Switching modals always begins from a clean slate to avoid overlapping UI states.
	_hide_all_panels()
	active_modal = modal
	var panel := _panels.get(modal) as Control
	if panel:
		panel.visible = true
	# Pause, cursor, and crosshair are one modal invariant; changing one without the others creates broken input states.
	get_tree().paused = modal != NONE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if modal != NONE else Input.MOUSE_MODE_CAPTURED
	if _crosshair:
		_crosshair.visible = modal == NONE


func close(modal: StringName) -> bool:
	# Ignore stale close requests for modals that are no longer active.
	if active_modal != modal:
		return false
	open(NONE)
	return true


func is_open(modal: StringName) -> bool:
	return active_modal == modal


func has_open_modal() -> bool:
	return active_modal != NONE


func get_registered_panel(modal: StringName) -> GamePanel:
	return _panels.get(modal) as GamePanel


func release_for_exit() -> void:
	_hide_all_panels()
	active_modal = NONE
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _crosshair:
		_crosshair.visible = false


func _hide_all_panels() -> void:
	# Registered panels are toggled centrally so panel scripts can stay stateless.
	for panel in _panels.values():
		if panel:
			panel.visible = false
