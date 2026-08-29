@tool
## Lightweight Modal Manager that tracks open panels, pauses the game, and captures the mouse.
class_name ModalManager
extends Node

const NONE := &""
const GROUP_WORLD_UI_CONTROLLER := "world_ui_controller"

@export var active_registry: UIRegistry

var active_modal: StringName = NONE
var _panels: Dictionary[StringName, GamePanel] = {}

var can_pause := false
var _pending_inventory: InventoryStore

func _ready() -> void:
	add_to_group(GROUP_WORLD_UI_CONTROLLER)
	if not Engine.is_editor_hint():
		_setup_internal_controllers()

func _setup_internal_controllers() -> void:
	var menu_ui = get_node_or_null("MenuLayer/MenuUI")
	if menu_ui:
		for child in menu_ui.get_children():
			if child is GamePanel:
				_bind_and_register_panel(child)
				
	if active_registry:
		var panels_layer = get_node_or_null("GamePanelsLayer")
		if panels_layer:
			for packed_scene in active_registry.registered_panels:
				if packed_scene:
					var instance = packed_scene.instantiate()
					panels_layer.add_child(instance)
					if instance is GamePanel:
						_bind_and_register_panel(instance)

func _bind_and_register_panel(panel: GamePanel) -> void:
	register_modal_panel(panel)
	
	if panel.has_signal("load_game_pressed") and not panel.load_game_pressed.is_connected(self._open_load_menu):
		panel.load_game_pressed.connect(self._open_load_menu)
	if panel.has_signal("quit_to_menu_pressed") and not panel.has_meta("quit_bound"):
		panel.quit_to_menu_pressed.connect(func(): ServiceRegistry.world.quit_to_menu())
		panel.set_meta("quit_bound", true)


func _open_load_menu() -> void:
	open(&"load_menu")


func register_modal_panel(panel: GamePanel) -> void:
	if panel == null or panel.modal_id == NONE:
		return
	_panels[panel.modal_id] = panel
	if active_modal != panel.modal_id:
		panel.visible = false
	if not panel.closed.is_connected(_on_panel_closed.bind(panel.modal_id)):
		panel.closed.connect(_on_panel_closed.bind(panel.modal_id))


func open(modal: StringName) -> void:
	if modal != NONE and not _panels.has(modal):
		push_warning("Cannot open unregistered modal '%s'." % modal)
		return
	_hide_all_panels()
	active_modal = modal
	var panel := _panels.get(modal) as GamePanel
	if panel:
		panel.visible = true
	var should_pause = modal != NONE and panel != null and panel.pauses_game
	get_tree().paused = should_pause
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if modal != NONE else Input.MOUSE_MODE_CAPTURED

func close(modal: StringName) -> bool:
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

func _hide_all_panels() -> void:
	for panel in _panels.values():
		if panel:
			panel.visible = false

func start_world_session(show_intro: bool) -> void:
	can_pause = not show_intro
	open(&"intro" if show_intro else NONE)
	if show_intro:
		var intro_panel = get_registered_panel(&"intro")
		if intro_panel:
			var btn = intro_panel.get_node_or_null("%IntroContinue")
			if btn: btn.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not can_pause:
		return

	if event.is_action_pressed("inventory_toggle") and (is_open(NONE) or is_open(&"inventory")):
		var inv := get_registered_panel(&"inventory")
		if inv:
			if is_open(&"inventory"):
				inv.call("close_panel")
			else:
				inv.call("open_panel")
				open(&"inventory")
		return
		
	if event.is_action_pressed("ui_cancel"):
		match active_modal:
			&"pause":
				var panel := get_registered_panel(active_modal)
				if panel: panel.close_panel()
			NONE:
				open(&"pause")
			_:
				var panel := get_registered_panel(active_modal)
				if panel: panel.close_panel()

func _on_panel_closed(modal_id: StringName) -> void:
	if modal_id == &"intro":
		can_pause = true
	close(modal_id)

func set_runtime_player(_runtime_player: Node) -> void:
	# Handled elsewhere now, but kept for compatibility with BaseLevel API calls if needed.
	pass

func bind_dialogue_state_source(_dialogue_state: Node) -> void:
	pass

func bind_inventory_store(_inventory: Resource) -> void:
	pass
