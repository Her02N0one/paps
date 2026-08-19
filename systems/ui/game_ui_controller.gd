@tool
## Central UI orchestrator for world runtime: modal gating, interaction routing, and hint updates.
class_name GameUIController
extends Node

signal quit_to_menu_requested
signal quit_game_requested

const MODAL_INTRO    := &"intro"
const MODAL_PAUSE    := &"pause"
const MODAL_EXAMINE  := &"examine"
const MODAL_DIALOGUE := &"dialogue"
const MODAL_INVENTORY := &"inventory"
const MODAL_SCRAPPING := &"scrapping"
const MODAL_LOAD_MENU := &"load_menu"
const NONE := &""
const UI_INTERACTION_ROUTER_SCRIPT := preload("res://systems/interaction/ui_interaction_router.gd")
const GROUP_WORLD_UI_CONTROLLER := "world_ui_controller"
@export var hud_path: NodePath
@export var intro_panel_path: NodePath
@export var pause_panel_path: NodePath
@export var load_menu_panel_path: NodePath = NodePath("MenuLayer/MenuUI/LoadMenuPanel")
@export var interact_hint_path: NodePath
@export var crosshair_path: NodePath

var player: Player
var hud: Control
var intro_panel: Control
var pause_panel: Control
var load_menu_panel: Control
var interact_hint: Label
var crosshair: Label
var time_label: Label
var active_modal: StringName = NONE
var _panels: Dictionary[StringName, GamePanel] = {}

var _focused_interactable: Interactable
var _interaction_router: Variant = UI_INTERACTION_ROUTER_SCRIPT.new()
var _dialogue_state: Node
var _pending_inventory: InventoryStore

var can_pause := false
func _ready() -> void:
	add_to_group(GROUP_WORLD_UI_CONTROLLER)
	_resolve_scene_nodes()
	if Engine.is_editor_hint():
		update_configuration_warnings()
	if hud:
		hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Engine.is_editor_hint():
		_setup_internal_controllers()
		var tm = get_node_or_null("/root/TimeManager")
		if tm and time_label:
			tm.time_changed.connect(_on_time_changed)
			var gs = get_tree().get_first_node_in_group("game_state") as GameState
			if gs:
				_on_time_changed(gs.current_day, gs.current_time_minutes)
	_register_interaction_handlers()
	_warn_if_player_missing.call_deferred()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if hud_path.is_empty():
		warnings.append("hud_path is empty.")
	if intro_panel_path.is_empty():
		warnings.append("intro_panel_path is empty.")
	if pause_panel_path.is_empty():
		warnings.append("pause_panel_path is empty.")
	if interact_hint_path.is_empty():
		warnings.append("interact_hint_path is empty.")
	if crosshair_path.is_empty():
		warnings.append("crosshair_path is empty.")
	return warnings


func _setup_internal_controllers() -> void:
	if intro_panel is GamePanel:
		register_modal_panel(intro_panel as GamePanel)
	if pause_panel is GamePanel:
		register_modal_panel(pause_panel as GamePanel)
	if load_menu_panel is GamePanel:
		register_modal_panel(load_menu_panel as GamePanel)

	if intro_panel and intro_panel.has_signal("continue_pressed"):
		if not intro_panel.continue_pressed.is_connected(_on_intro_continue_pressed):
			intro_panel.continue_pressed.connect(_on_intro_continue_pressed)
	if pause_panel:
		if pause_panel.has_signal("resume_pressed") and not pause_panel.resume_pressed.is_connected(_on_resume_pressed):
			pause_panel.resume_pressed.connect(_on_resume_pressed)
		if pause_panel.has_signal("quick_save_pressed") and not pause_panel.quick_save_pressed.is_connected(self._emit_quick_save):
			pause_panel.quick_save_pressed.connect(self._emit_quick_save)
		if pause_panel.has_signal("load_game_pressed") and not pause_panel.load_game_pressed.is_connected(self._open_load_menu):
			pause_panel.load_game_pressed.connect(self._open_load_menu)
		if pause_panel.has_signal("quit_to_menu_pressed") and not pause_panel.quit_to_menu_pressed.is_connected(self._emit_quit_to_menu):
			pause_panel.quit_to_menu_pressed.connect(self._emit_quit_to_menu)
		if pause_panel.has_signal("quit_game_pressed") and not pause_panel.quit_game_pressed.is_connected(self._emit_quit_game):
			pause_panel.quit_game_pressed.connect(self._emit_quit_game)
		if pause_panel.has_signal("manual_save_pressed") and not pause_panel.manual_save_pressed.is_connected(self._emit_manual_save):
			pause_panel.manual_save_pressed.connect(self._emit_manual_save)

func _emit_quick_save() -> void:
	var root = get_node_or_null("/root/RootContext")
	if root and root.has_method("get_save_manager"):
		if root.get_save_manager().save_game("quick"):
			if pause_panel.has_method("show_status"):
				pause_panel.show_status("Game Saved!")
		else:
			if pause_panel.has_method("show_status"):
				pause_panel.show_status("Save Failed!")

func _emit_manual_save() -> void:
	var root = get_node_or_null("/root/RootContext")
	if root and root.has_method("get_save_manager"):
		if root.get_save_manager().save_game("manual"):
			if pause_panel.has_method("show_status"):
				pause_panel.show_status("GAME SAVED!")
		else:
			if pause_panel.has_method("show_status"):
				pause_panel.show_status("SAVE FAILED!")

func _open_load_menu() -> void:
	open(MODAL_LOAD_MENU)

func _emit_quit_to_menu() -> void:
	quit_to_menu_requested.emit()

func _emit_quit_game() -> void:
	quit_game_requested.emit()


func register_modal_panel(panel: GamePanel) -> void:
	if panel == null or panel.modal_id == NONE:
		return
	_panels[panel.modal_id] = panel
	if active_modal != panel.modal_id:
		panel.visible = false
	if not panel.closed.is_connected(_on_panel_closed.bind(panel.modal_id)):
		panel.closed.connect(_on_panel_closed.bind(panel.modal_id))
	if panel is InventoryPanel:
		var inv := panel as InventoryPanel
		inv.set_action_user(player)
		if _pending_inventory:
			inv.bind_inventory(_pending_inventory)


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
	if crosshair:
		crosshair.visible = modal == NONE

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
	if crosshair:
		crosshair.visible = false

func _hide_all_panels() -> void:
	for panel in _panels.values():
		if panel:
			panel.visible = false


func bind_dialogue_state_source(dialogue_state: Node) -> void:
	_dialogue_state = dialogue_state


func bind_inventory_store(inventory: InventoryStore) -> void:
	_pending_inventory = inventory
	var panel := get_registered_panel(MODAL_INVENTORY) as InventoryPanel
	if panel:
		panel.bind_inventory(inventory)


func _register_interaction_handlers() -> void:
	register_player_interaction(PlayerInteractionRequest.EXAMINE, _handle_examine_request)
	register_player_interaction(PlayerInteractionRequest.SCRAPPING, _handle_scrapping_request)
	register_player_interaction(PlayerInteractionRequest.DIALOGUE, _handle_dialogue_request)


func set_runtime_player(runtime_player: Player) -> void:
	if player and player != runtime_player and player.interactable_changed.is_connected(_on_interactable_changed):
		player.interactable_changed.disconnect(_on_interactable_changed)
	player = runtime_player
	if player and not player.interactable_changed.is_connected(_on_interactable_changed):
		player.interactable_changed.connect(_on_interactable_changed)
	var inventory_panel := get_registered_panel(MODAL_INVENTORY) as InventoryPanel
	if inventory_panel:
		inventory_panel.set_action_user(player)
	_refresh_interact_hint()


func start_world_session(show_intro: bool) -> void:
	can_pause = not show_intro
	if interact_hint:
		interact_hint.visible = false
	open(MODAL_INTRO if show_intro else NONE)
	if show_intro and intro_panel:
		var btn = intro_panel.get_node_or_null("IntroMargin/IntroVBox/IntroContinue")
		if btn:
			btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not can_pause:
		return

	if event.is_action_pressed("inventory_toggle") and (
		is_open(NONE) or is_open(MODAL_INVENTORY)
	):
		var inv := get_registered_panel(MODAL_INVENTORY) as InventoryPanel
		if inv:
			if is_open(MODAL_INVENTORY):
				inv.close_panel()
			else:
				inv.open_panel()
				open(MODAL_INVENTORY)
		return
		
	if event.is_action_pressed("ui_cancel"):
		match active_modal:
			MODAL_PAUSE:
				_on_resume_pressed()
			NONE:
				_open_pause_menu()
			_:
				var panel := get_registered_panel(active_modal)
				if panel:
					panel.close_panel()

func _on_intro_continue_pressed() -> void:
	can_pause = true
	close(MODAL_INTRO)

func _open_pause_menu() -> void:
	open(MODAL_PAUSE)
	if interact_hint:
		interact_hint.visible = false

func _on_resume_pressed() -> void:
	close(MODAL_PAUSE)
	_refresh_interact_hint()


func register_player_interaction(action: StringName, handler: Callable) -> void:
	_interaction_router.register_route(action, handler)


func unregister_player_interaction(action: StringName) -> void:
	_interaction_router.unregister_route(action)


func _on_interactable_changed(interactable) -> void:
	var new_focused_interactable := _as_valid_interactable(interactable)
	if interact_hint:
		interact_hint.visible = new_focused_interactable != null and not has_open_modal()
	if new_focused_interactable and interact_hint:
		interact_hint.text = "[E]  " + new_focused_interactable.interact_label
	if is_instance_valid(_focused_interactable) and _focused_interactable.player_interaction_requested.is_connected(_on_player_interaction_requested):
		_focused_interactable.player_interaction_requested.disconnect(_on_player_interaction_requested)
	_focused_interactable = new_focused_interactable
	if _focused_interactable:
		_focused_interactable.player_interaction_requested.connect(_on_player_interaction_requested)


func _as_valid_interactable(candidate: Variant) -> Interactable:
	return candidate as Interactable if is_instance_valid(candidate) and candidate is Interactable else null


func _on_player_interaction_requested(request: PlayerInteractionRequest) -> void:
	if not _interaction_router.dispatch(request):
		push_warning("No player interaction handler registered for '%s'." % request.action)


func _resolve_scene_nodes() -> void:
	hud = _strict_resolve(hud_path, "HUD") as Control
	intro_panel = _strict_resolve(intro_panel_path, "IntroPanel") as Control
	pause_panel = _strict_resolve(pause_panel_path, "PausePanel") as Control
	if not load_menu_panel_path.is_empty():
		load_menu_panel = get_node_or_null(load_menu_panel_path) as Control
	interact_hint = _strict_resolve(interact_hint_path, "InteractHint") as Label
	crosshair = _strict_resolve(crosshair_path, "CrossHair") as Label
	time_label = hud.get_node_or_null("TimeLabel") if hud else null

func _strict_resolve(path: NodePath, debug_name: String) -> Node:
	if path.is_empty():
		push_error("GameUIController: NodePath for '%s' is empty. It must be assigned in the inspector." % debug_name)
		return null
	var node := get_node_or_null(path)
	if node == null:
		push_error("GameUIController: Could not resolve NodePath '%s' for '%s'." % [path, debug_name])
	return node


func _warn_if_player_missing() -> void:
	if player == null:
		push_warning("GameUIController: player could not be resolved; interaction hint updates are disabled.")


func _handle_examine_request(request: PlayerInteractionRequest) -> void:
	var panel := get_registered_panel(MODAL_EXAMINE) as ExaminePanel
	if panel == null:
		return
	panel.show_content(str(request.payload.get("title", "")), str(request.payload.get("content", "")))
	open(MODAL_EXAMINE)
	if interact_hint:
		interact_hint.visible = false


func _handle_dialogue_request(request: PlayerInteractionRequest) -> void:
	var conversation := request.payload.get("conversation") as DialogueConversation
	var person_def := request.payload.get("person_definition") as PersonDefinition
	if conversation == null:
		conversation = _create_single_line_dialogue(request.payload)
	var context := DialogueContext.new(request.initiating_actor, request.interactable, _dialogue_state)
	var panel := get_registered_panel(MODAL_DIALOGUE) as DialoguePanel
	if panel == null:
		return
	if panel.open_dialogue(conversation, context, person_def):
		open(MODAL_DIALOGUE)
		if interact_hint:
			interact_hint.visible = false


func _create_single_line_dialogue(payload: Dictionary) -> DialogueConversation:
	var dialogue_node := DialogueNode.new()
	dialogue_node.id = &"message"
	dialogue_node.speaker = str(payload.get("speaker", "Person"))
	dialogue_node.text = str(payload.get("text", ""))
	var conversation := DialogueConversation.new()
	conversation.id = &"single_line"
	conversation.entry_node_id = dialogue_node.id
	conversation.nodes = [dialogue_node]
	return conversation


func _handle_scrapping_request(request: PlayerInteractionRequest) -> void:
	var inventory_holder := InventoryHolderComponent.find_on(request.initiating_actor)
	if inventory_holder == null or inventory_holder.inventory == null:
		return
	var panel := get_registered_panel(MODAL_SCRAPPING) as ScrappingPanel
	if panel == null:
		return
	panel.show_inventory(inventory_holder.inventory)
	open(MODAL_SCRAPPING)
	if interact_hint:
		interact_hint.visible = false


func _on_panel_closed(modal_id: StringName) -> void:
	close(modal_id)
	_refresh_interact_hint()


func _refresh_interact_hint() -> void:
	if player == null:
		return
	_on_interactable_changed(player.get_current_interactable())

func _on_time_changed(day: int, minutes: float) -> void:
	if time_label:
		var hours := int(minutes) / 60
		var mins := int(minutes) % 60
		time_label.text = "DAY %d, %02d:%02d" % [day, hours, mins]
