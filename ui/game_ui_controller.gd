@tool
## Central UI orchestrator for world runtime: modal gating, interaction routing, and hint updates.
class_name GameUIController
extends Node

signal quit_to_menu_requested
signal quit_game_requested

const NONE := &""
const UI_INTERACTION_ROUTER_SCRIPT := preload("res://features/interaction/ui_interaction_router.gd")
const GROUP_WORLD_UI_CONTROLLER := "world_ui_controller"
@onready var hud: Control = $HUDLayer/HUD
@onready var interact_hint: Label = $HUDLayer/HUD/InteractHint
@onready var crosshair: Label = $HUDLayer/HUD/CrossHair

var player: Player
var active_modal: StringName = NONE
var _panels: Dictionary[StringName, GamePanel] = {}

var _focused_interactable: Interactable
var _interaction_router: Variant = UI_INTERACTION_ROUTER_SCRIPT.new()
var _dialogue_state: Node
var _pending_inventory: InventoryStore

var can_pause := false
func _ready() -> void:
	add_to_group(GROUP_WORLD_UI_CONTROLLER)
	if hud:
		hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Engine.is_editor_hint():
		_setup_internal_controllers()
		# Time logic has been decoupled to hud_time_label.gd
	_register_interaction_handlers()
	_warn_if_player_missing.call_deferred()



func _setup_internal_controllers() -> void:
	var menu_ui = get_node("MenuLayer/MenuUI")
		
	for child in menu_ui.get_children():
		if child is GamePanel:
			register_modal_panel(child)
			
			# Bind high-level routing signals dynamically if the panel supports them
			if child.has_signal("load_game_pressed") and not child.load_game_pressed.is_connected(self._open_load_menu):
				child.load_game_pressed.connect(self._open_load_menu)
			if child.has_signal("quit_to_menu_pressed") and not child.quit_to_menu_pressed.is_connected(self._emit_quit_to_menu):
				child.quit_to_menu_pressed.connect(self._emit_quit_to_menu)
			if child.has_signal("quit_game_pressed") and not child.quit_game_pressed.is_connected(self._emit_quit_game):
				child.quit_game_pressed.connect(self._emit_quit_game)

# ==============================================================================
# Modal State Management
# ==============================================================================

# ==============================================================================
# Top-Level Flow Events
# ==============================================================================

func _open_load_menu() -> void:
	open(&"load_menu")

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


# ==============================================================================
# UI Interaction & Bindings
# ==============================================================================
func bind_dialogue_state_source(dialogue_state: Node) -> void:
	_dialogue_state = dialogue_state


func bind_inventory_store(inventory: InventoryStore) -> void:
	_pending_inventory = inventory
	var panel := get_registered_panel(&"inventory") as InventoryPanel
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
	var inventory_panel := get_registered_panel(&"inventory") as InventoryPanel
	if inventory_panel:
		inventory_panel.set_action_user(player)
	_refresh_interact_hint()


func start_world_session(show_intro: bool) -> void:
	can_pause = not show_intro
	if interact_hint:
		interact_hint.visible = false
	open(&"intro" if show_intro else NONE)
	if show_intro:
		var intro_panel = get_registered_panel(&"intro")
		if intro_panel:
			var btn = intro_panel.get_node("IntroMargin/IntroVBox/IntroContinue")
			btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not can_pause:
		return

	if event.is_action_pressed("inventory_toggle") and (
		is_open(NONE) or is_open(&"inventory")
	):
		var inv := get_registered_panel(&"inventory") as InventoryPanel
		if inv:
			if is_open(&"inventory"):
				inv.close_panel()
			else:
				inv.open_panel()
				open(&"inventory")
		return
		
	if event.is_action_pressed("ui_cancel"):
		match active_modal:
			&"pause":
				var panel := get_registered_panel(active_modal)
				if panel:
					panel.close_panel()
			NONE:
				_open_pause_menu()
			_:
				var panel := get_registered_panel(active_modal)
				if panel:
					panel.close_panel()

func _open_pause_menu() -> void:
	open(&"pause")
	if interact_hint:
		interact_hint.visible = false


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





func _warn_if_player_missing() -> void:
	if Engine.is_editor_hint():
		return
	if player == null:
		push_warning("GameUIController: player could not be resolved; interaction hint updates are disabled.")


func _handle_examine_request(request: PlayerInteractionRequest) -> void:
	var panel := get_registered_panel(&"examine") as ExaminePanel
	if panel == null:
		return
	panel.show_content(str(request.payload.get("title", "")), str(request.payload.get("content", "")))
	open(&"examine")
	if interact_hint:
		interact_hint.visible = false


func _handle_dialogue_request(request: PlayerInteractionRequest) -> void:
	var conversation := request.payload.get("conversation") as DialogueConversation
	var person_def := request.payload.get("person_definition") as PersonDefinition
	if conversation == null:
		conversation = _create_single_line_dialogue(request.payload)
	var context := DialogueContext.new(request.initiating_actor, request.interactable, _dialogue_state)
	var panel := get_registered_panel(&"dialogue") as DialoguePanel
	if panel == null:
		return
	if panel.open_dialogue(conversation, context, person_def):
		open(&"dialogue")
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
	var panel := get_registered_panel(&"scrapping") as ScrappingPanel
	if panel == null:
		return
	panel.show_inventory(inventory_holder.inventory)
	open(&"scrapping")
	if interact_hint:
		interact_hint.visible = false


func _on_panel_closed(modal_id: StringName) -> void:
	if modal_id == &"intro":
		can_pause = true
	close(modal_id)
	_refresh_interact_hint()


func _refresh_interact_hint() -> void:
	if player == null:
		return
	_on_interactable_changed(player.get_current_interactable())

# ==============================================================================
