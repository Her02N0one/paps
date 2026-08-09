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

var can_pause := false
var _focused_panel: InteractablePanel


func _ready() -> void:
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.interactable_changed.connect(_on_interactable_changed)
	inventory_panel.opened.connect(_on_inventory_opened)
	inventory_panel.closed.connect(_on_inventory_closed)
	inventory_panel.set_action_user(player)


func begin_session(show_intro: bool) -> void:
	intro_panel.visible = show_intro
	pause_panel.visible = false
	can_pause = not show_intro
	get_tree().paused = show_intro
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if show_intro else Input.MOUSE_MODE_CAPTURED
	crosshair.visible = not show_intro
	interact_hint.visible = false
	if show_intro:
		intro_panel.get_node("IntroMargin/IntroVBox/IntroContinue").grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not can_pause:
		return
	if event.is_action_pressed("inventory_toggle") and not pause_panel.visible and not examine_panel.visible:
		inventory_panel.toggle_panel()
		return
	if event.is_action_pressed("ui_cancel"):
		if inventory_panel.visible:
			inventory_panel.close_panel()
		elif examine_panel.visible:
			_on_examine_close_pressed()
		elif get_tree().paused:
			_resume_game()
		else:
			_open_pause_menu()


func _on_interactable_changed(interactable) -> void:
	var valid_interactable: Interactable = interactable if is_instance_valid(interactable) and interactable is Interactable else null
	interact_hint.visible = valid_interactable != null and not examine_panel.visible and not inventory_panel.visible and not pause_panel.visible
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
	examine_panel.visible = true
	interact_hint.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_intro_continue_pressed() -> void:
	intro_panel.visible = false
	can_pause = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	crosshair.visible = true


func _on_resume_pressed() -> void:
	_resume_game()


func _on_examine_close_pressed() -> void:
	examine_panel.visible = false
	_resume_game()


func _on_quit_to_menu_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	quit_to_menu_requested.emit()


func _on_quit_game_pressed() -> void:
	get_tree().paused = false
	quit_game_requested.emit()


func _open_pause_menu() -> void:
	pause_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	crosshair.visible = false
	interact_hint.visible = false


func _resume_game() -> void:
	pause_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	crosshair.visible = true
	_on_interactable_changed(player.get_current_interactable())


func _on_inventory_opened() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	crosshair.visible = false
	interact_hint.visible = false


func _on_inventory_closed() -> void:
	_resume_game()