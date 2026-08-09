class_name GameUIController
extends Node

signal quit_to_menu_requested
signal quit_game_requested

@export var player_path: NodePath
@export var hud_path: NodePath
@export var intro_panel_path: NodePath
@export var pause_panel_path: NodePath
@export var interact_hint_path: NodePath
@export var crosshair_path: NodePath
@export var examine_panel_path: NodePath
@export var inventory_panel_path: NodePath

@onready var player: CharacterBody3D = get_node(player_path)
@onready var hud: Control = get_node(hud_path)
@onready var intro_panel: Control = get_node(intro_panel_path)
@onready var pause_panel: Control = get_node(pause_panel_path)
@onready var interact_hint: Label = get_node(interact_hint_path)
@onready var crosshair: Label = get_node(crosshair_path)
@onready var examine_panel: PanelContainer = get_node(examine_panel_path)
@onready var inventory_panel: InventoryPanel = get_node(inventory_panel_path)
@onready var examine_title: Label = examine_panel.get_node("VBox/Title")
@onready var examine_content: Label = examine_panel.get_node("VBox/Content")
@onready var modal_state: ModalStateController = get_node("../ModalStateController")

var can_pause := false
var _focused_panel: InteractablePanel


func _ready() -> void:
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_state.configure(intro_panel, pause_panel, examine_panel, inventory_panel, crosshair)
	player.interactable_changed.connect(_on_interactable_changed)
	inventory_panel.opened.connect(_on_inventory_opened)
	inventory_panel.closed.connect(_on_inventory_closed)
	inventory_panel.set_action_user(player)


func begin_session(show_intro: bool) -> void:
	can_pause = not show_intro
	modal_state.open(ModalStateController.Modal.INTRO if show_intro else ModalStateController.Modal.NONE)
	interact_hint.visible = false
	if show_intro:
		intro_panel.get_node("IntroMargin/IntroVBox/IntroContinue").grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not can_pause:
		return
	if event.is_action_pressed("inventory_toggle") and (
		modal_state.is_open(ModalStateController.Modal.NONE)
		or modal_state.is_open(ModalStateController.Modal.INVENTORY)
	):
		inventory_panel.toggle_panel()
		return
	if event.is_action_pressed("ui_cancel"):
		match modal_state.active_modal:
			ModalStateController.Modal.INVENTORY:
				inventory_panel.close_panel()
			ModalStateController.Modal.EXAMINE:
				_on_examine_close_pressed()
			ModalStateController.Modal.PAUSE:
				_resume_game()
			ModalStateController.Modal.NONE:
				_open_pause_menu()


func _on_interactable_changed(interactable) -> void:
	var valid_interactable: Interactable = interactable if is_instance_valid(interactable) and interactable is Interactable else null
	interact_hint.visible = valid_interactable != null and not modal_state.has_open_modal()
	if valid_interactable:
		interact_hint.text = "[E]  " + valid_interactable.interact_label
	if is_instance_valid(_focused_panel) and _focused_panel.opened.is_connected(_on_panel_opened):
		_focused_panel.opened.disconnect(_on_panel_opened)
	_focused_panel = valid_interactable as InteractablePanel if valid_interactable is InteractablePanel else null
	if _focused_panel:
		_focused_panel.opened.connect(_on_panel_opened)


func _on_panel_opened(panel: InteractablePanel) -> void:
	examine_title.text = panel.panel_title
	examine_content.text = panel.content
	modal_state.open(ModalStateController.Modal.EXAMINE)
	interact_hint.visible = false


func _on_intro_continue_pressed() -> void:
	can_pause = true
	modal_state.close(ModalStateController.Modal.INTRO)


func _on_resume_pressed() -> void:
	_resume_game()


func _on_examine_close_pressed() -> void:
	modal_state.close(ModalStateController.Modal.EXAMINE)
	_refresh_interact_hint()


func _on_quit_to_menu_pressed() -> void:
	modal_state.release_for_exit()
	quit_to_menu_requested.emit()


func _on_quit_game_pressed() -> void:
	modal_state.release_for_exit()
	quit_game_requested.emit()


func _open_pause_menu() -> void:
	modal_state.open(ModalStateController.Modal.PAUSE)
	interact_hint.visible = false


func _resume_game() -> void:
	modal_state.close(ModalStateController.Modal.PAUSE)
	_refresh_interact_hint()


func _on_inventory_opened() -> void:
	modal_state.open(ModalStateController.Modal.INVENTORY)
	interact_hint.visible = false


func _on_inventory_closed() -> void:
	modal_state.close(ModalStateController.Modal.INVENTORY)
	_refresh_interact_hint()


func _refresh_interact_hint() -> void:
	_on_interactable_changed(player.get_current_interactable())
