class_name ModalStateController
extends Node

enum Modal { NONE, INTRO, PAUSE, EXAMINE, INVENTORY }

var active_modal := Modal.NONE
var _intro_panel: Control
var _pause_panel: Control
var _examine_panel: Control
var _inventory_panel: Control
var _crosshair: Control


func configure(
	intro_panel: Control,
	pause_panel: Control,
	examine_panel: Control,
	inventory_panel: Control,
	crosshair: Control
) -> void:
	_intro_panel = intro_panel
	_pause_panel = pause_panel
	_examine_panel = examine_panel
	_inventory_panel = inventory_panel
	_crosshair = crosshair
	_hide_all_panels()


func open(modal: Modal) -> void:
	_hide_all_panels()
	active_modal = modal
	var panel := _get_panel(modal)
	if panel:
		panel.visible = true
	get_tree().paused = modal != Modal.NONE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if modal != Modal.NONE else Input.MOUSE_MODE_CAPTURED
	_crosshair.visible = modal == Modal.NONE


func close(modal: Modal) -> bool:
	if active_modal != modal:
		return false
	open(Modal.NONE)
	return true


func is_open(modal: Modal) -> bool:
	return active_modal == modal


func has_open_modal() -> bool:
	return active_modal != Modal.NONE


func release_for_exit() -> void:
	_hide_all_panels()
	active_modal = Modal.NONE
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_crosshair.visible = false


func _get_panel(modal: Modal) -> Control:
	match modal:
		Modal.INTRO:
			return _intro_panel
		Modal.PAUSE:
			return _pause_panel
		Modal.EXAMINE:
			return _examine_panel
		Modal.INVENTORY:
			return _inventory_panel
		_:
			return null


func _hide_all_panels() -> void:
	for panel in [_intro_panel, _pause_panel, _examine_panel, _inventory_panel]:
		if panel:
			panel.visible = false