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
const UI_INTERACTION_ROUTER_SCRIPT := preload("res://scripts/features/ui/interactions/ui_interaction_router.gd")
const GROUP_WORLD_UI_CONTROLLER := "world_ui_controller"
const GROUP_LEGACY_UI_COORDINATOR := "ui_coordinator"

# System UI — not interactive panels, so wired individually.
@export var player_path: NodePath
@export var hud_path: NodePath
@export var intro_panel_path: NodePath
@export var pause_panel_path: NodePath
@export var interact_hint_path: NodePath
@export var crosshair_path: NodePath
@export var auto_resolve_scene_nodes := true

var player: Player
var hud: Control
var intro_panel: Control
var pause_panel: Control
var interact_hint: Label
var crosshair: Label
var combat_feedback: Label
var health_readout: Label
var damage_flash: ColorRect
# Falls back to sibling path so existing scenes work before the export is wired.
@onready var modal_state: ModalStateController = get_node_or_null("%ModalStateController") \
	if has_node("%ModalStateController") else get_node("../ModalStateController") as ModalStateController

var can_pause := false
var _focused_interactable: Interactable
var _interaction_router: Variant = UI_INTERACTION_ROUTER_SCRIPT.new()
var _dialogue_state: Node
var _pending_inventory: InventoryStore
var _player_weapon_component: PlayerWeaponComponent
var _player_health_component: ActorHealthComponent
var _combat_feedback_timer := 0.0
var _damage_flash_alpha := 0.0

const COMBAT_FEEDBACK_DURATION := 0.22
const DAMAGE_FLASH_DECAY_PER_SEC := 2.4
const CROSSHAIR_DEFAULT_COLOR := Color(1, 1, 1, 1)
const CROSSHAIR_HIT_COLOR := Color(1, 0.38, 0.2, 1)


func _ready() -> void:
	add_to_group(GROUP_WORLD_UI_CONTROLLER)
	add_to_group(GROUP_LEGACY_UI_COORDINATOR)
	_resolve_scene_nodes()
	# Keep editor feedback active without blocking runtime setup in play mode.
	if Engine.is_editor_hint():
		update_configuration_warnings()
	# HUD is presentation-only and should not consume pointer events.
	if hud:
		hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_configure_modal_panels()
	_register_interaction_handlers()
	_connect_ui_signals()
	_bind_player_combat_signals()
	_update_health_readout()
	_warn_if_player_missing.call_deferred()


func _process(delta: float) -> void:
	if _combat_feedback_timer > 0.0:
		_combat_feedback_timer = maxf(_combat_feedback_timer - delta, 0.0)
		if _combat_feedback_timer <= 0.0:
			if combat_feedback:
				combat_feedback.visible = false
			if crosshair:
				crosshair.modulate = CROSSHAIR_DEFAULT_COLOR
	if _damage_flash_alpha > 0.0:
		_damage_flash_alpha = maxf(_damage_flash_alpha - DAMAGE_FLASH_DECAY_PER_SEC * delta, 0.0)
	if damage_flash:
		damage_flash.modulate.a = _damage_flash_alpha


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	# Modal state controller is mandatory for all open/close routing.
	if modal_state == null:
		warnings.append("GameUIController requires a ModalStateController sibling or unique-name node.")
	# Manual wiring mode expects each exported path to be configured.
	if not auto_resolve_scene_nodes:
		if player_path.is_empty():
			warnings.append("player_path is empty while auto_resolve_scene_nodes is disabled.")
		if hud_path.is_empty():
			warnings.append("hud_path is empty while auto_resolve_scene_nodes is disabled.")
		if intro_panel_path.is_empty():
			warnings.append("intro_panel_path is empty while auto_resolve_scene_nodes is disabled.")
		if pause_panel_path.is_empty():
			warnings.append("pause_panel_path is empty while auto_resolve_scene_nodes is disabled.")
		if interact_hint_path.is_empty():
			warnings.append("interact_hint_path is empty while auto_resolve_scene_nodes is disabled.")
		if crosshair_path.is_empty():
			warnings.append("crosshair_path is empty while auto_resolve_scene_nodes is disabled.")
	if modal_state == null and not Engine.is_editor_hint():
		warnings.append("ModalStateController resolution failed; modal open/close flow will not work.")
	return warnings


## Called by each GamePanel from its own _ready() via deferred call.
func register_modal_panel(panel: GamePanel) -> void:
	modal_state.register_panel(panel.modal_id, panel)
	panel.closed.connect(_on_panel_closed.bind(panel.modal_id))
	# Inventory panel needs extra runtime dependencies that generic GamePanel does not expose.
	if panel is InventoryPanel:
		var inv := panel as InventoryPanel
		inv.set_action_user(player)
		# Inventory might bind before panel registration, so flush deferred bind here.
		if _pending_inventory:
			inv.bind_inventory(_pending_inventory)


func receive_panel(panel: GamePanel) -> void:
	register_modal_panel(panel)


func bind_dialogue_state_source(dialogue_state: Node) -> void:
	_dialogue_state = dialogue_state


func bind_dialogue_state(dialogue_state: Node) -> void:
	bind_dialogue_state_source(dialogue_state)


func bind_inventory_store(inventory: InventoryStore) -> void:
	_pending_inventory = inventory
	var panel := modal_state.get_registered_panel(MODAL_INVENTORY) as InventoryPanel
	# Apply immediately when panel already exists; otherwise deferred bind handles it later.
	if panel:
		panel.bind_inventory(inventory)


func bind_inventory(inventory: InventoryStore) -> void:
	bind_inventory_store(inventory)


func _configure_modal_panels() -> void:
	# System panels are wired directly; gameplay panels self-register via GamePanel._ready().
	modal_state.configure({
		MODAL_INTRO: intro_panel,
		MODAL_PAUSE: pause_panel,
	}, crosshair)


func _register_interaction_handlers() -> void:
	# New player-facing interaction types register here without adding concrete interactable checks.
	register_player_interaction(PlayerInteractionRequest.EXAMINE, _handle_examine_request)
	register_player_interaction(PlayerInteractionRequest.SCRAPPING, _handle_scrapping_request)
	register_player_interaction(PlayerInteractionRequest.DIALOGUE, _handle_dialogue_request)


func _connect_ui_signals() -> void:
	_connect_player_signal()
	# Intro button may not exist in stripped test scenes, so guard by signal presence.
	if intro_panel and intro_panel.has_signal("continue_pressed") and not intro_panel.continue_pressed.is_connected(_on_intro_continue_pressed):
		intro_panel.continue_pressed.connect(_on_intro_continue_pressed)
	if pause_panel:
		# Pause menu uses optional signal contract to stay compatible with lightweight stubs.
		if pause_panel.has_signal("resume_pressed") and not pause_panel.resume_pressed.is_connected(_on_resume_pressed):
			pause_panel.resume_pressed.connect(_on_resume_pressed)
		if pause_panel.has_signal("quit_to_menu_pressed") and not pause_panel.quit_to_menu_pressed.is_connected(_on_quit_to_menu_pressed):
			pause_panel.quit_to_menu_pressed.connect(_on_quit_to_menu_pressed)
		if pause_panel.has_signal("quit_game_pressed") and not pause_panel.quit_game_pressed.is_connected(_on_quit_game_pressed):
			pause_panel.quit_game_pressed.connect(_on_quit_game_pressed)


func set_runtime_player(runtime_player: Player) -> void:
	# Disconnect old actor first so stale focus updates do not outlive a player swap.
	if player and player != runtime_player and player.interactable_changed.is_connected(_on_interactable_changed):
		player.interactable_changed.disconnect(_on_interactable_changed)
	player = runtime_player
	_connect_player_signal()
	_bind_player_combat_signals()
	_update_health_readout()
	var inventory_panel := modal_state.get_registered_panel(MODAL_INVENTORY) as InventoryPanel
	# Inventory actions should always target the current runtime player.
	if inventory_panel:
		inventory_panel.set_action_user(player)
	_refresh_interact_hint()


func bind_runtime_player(runtime_player: Player) -> void:
	set_runtime_player(runtime_player)


func start_world_session(show_intro: bool) -> void:
	can_pause = not show_intro
	modal_state.open(MODAL_INTRO if show_intro else ModalStateController.NONE)
	if interact_hint:
		interact_hint.visible = false
	if show_intro and intro_panel:
		intro_panel.get_node("IntroMargin/IntroVBox/IntroContinue").grab_focus()


func begin_session(show_intro: bool) -> void:
	start_world_session(show_intro)


func _unhandled_input(event: InputEvent) -> void:
	# Pause and inventory controls stay locked until intro flow grants control.
	if not can_pause:
		return
	# Inventory toggle is only legal from gameplay idle state or while inventory itself is open.
	if event.is_action_pressed("inventory_toggle") and (
		modal_state.is_open(ModalStateController.NONE)
		or modal_state.is_open(MODAL_INVENTORY)
	):
		var inv := modal_state.get_registered_panel(MODAL_INVENTORY) as InventoryPanel
		if inv:
			if modal_state.is_open(MODAL_INVENTORY):
				inv.close_panel()
			else:
				inv.open_panel()
				modal_state.open(MODAL_INVENTORY)
		return
	if event.is_action_pressed("ui_cancel"):
		# Esc has context-sensitive meaning: resume pause, open pause, or close current modal.
		match modal_state.active_modal:
			MODAL_PAUSE:
				_resume_game()
			ModalStateController.NONE:
				_open_pause_menu()
			_:
				var panel := modal_state.get_registered_panel(modal_state.active_modal)
				# Unknown modals still get a polite close attempt through shared panel interface.
				if panel:
					panel.close_panel()


func register_player_interaction(action: StringName, handler: Callable) -> void:
	_interaction_router.register_route(action, handler)


func unregister_player_interaction(action: StringName) -> void:
	_interaction_router.unregister_route(action)


func _on_interactable_changed(interactable) -> void:
	var new_focused_interactable := _as_valid_interactable(interactable)
	# Hint is only visible when there is a valid target and no modal blocks interaction.
	if interact_hint:
		interact_hint.visible = new_focused_interactable != null and not modal_state.has_open_modal()
	# Label refresh happens only when both target and hint node are available.
	if new_focused_interactable and interact_hint:
		interact_hint.text = "[E]  " + new_focused_interactable.interact_label
	if is_instance_valid(_focused_interactable) and _focused_interactable.player_interaction_requested.is_connected(_on_player_interaction_requested):
		# Prevent stale signals from previous targets after focus changes.
		_focused_interactable.player_interaction_requested.disconnect(_on_player_interaction_requested)
	_focused_interactable = new_focused_interactable
	# Subscribe to the current target so interaction requests follow focus in real time.
	if _focused_interactable:
		_focused_interactable.player_interaction_requested.connect(_on_player_interaction_requested)


func _as_valid_interactable(candidate: Variant) -> Interactable:
	return candidate as Interactable if is_instance_valid(candidate) and candidate is Interactable else null


func _on_player_interaction_requested(request: PlayerInteractionRequest) -> void:
	if not _interaction_router.dispatch(request):
		push_warning("No player interaction handler registered for '%s'." % request.action)


func _resolve_scene_nodes() -> void:
	player = _resolve_node(player_path, "Player") as Player
	hud = _resolve_node(hud_path, "HUD") as Control
	intro_panel = _resolve_node(intro_panel_path, "IntroPanel") as Control
	pause_panel = _resolve_node(pause_panel_path, "PausePanel") as Control
	interact_hint = _resolve_node(interact_hint_path, "InteractHint") as Label
	crosshair = _resolve_node(crosshair_path, "CrossHair") as Label
	combat_feedback = _resolve_node(NodePath(), "CombatFeedback") as Label
	health_readout = _resolve_node(NodePath(), "HealthReadout") as Label
	damage_flash = _resolve_node(NodePath(), "DamageFlash") as ColorRect


func _resolve_node(path: NodePath, fallback_name: String) -> Node:
	# Explicit exported path wins when provided.
	if not path.is_empty():
		var by_path := get_node_or_null(path)
		# Valid explicit path short-circuits all fallback strategies.
		if by_path:
			return by_path
	# Unique-name lookup keeps scene contracts resilient to local hierarchy moves.
	var by_unique := get_node_or_null(NodePath("%%%s" % fallback_name))
	if by_unique:
		return by_unique
	# In strict mode we stop here so misconfigured paths are visible immediately.
	if not auto_resolve_scene_nodes:
		return null
	# Last-resort recursive lookup supports older scenes during migration.
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null
	return scene_root.find_child(fallback_name, true, false)


func _connect_player_signal() -> void:
	# Idempotent connect protects against duplicate callbacks during rebinding.
	if player and not player.interactable_changed.is_connected(_on_interactable_changed):
		player.interactable_changed.connect(_on_interactable_changed)


func _bind_player_combat_signals() -> void:
	var next_weapon := player.get_node_or_null("PlayerWeaponComponent") as PlayerWeaponComponent if player else null
	if _player_weapon_component != null and _player_weapon_component != next_weapon:
		if _player_weapon_component.weapon_fired.is_connected(_on_player_weapon_fired):
			_player_weapon_component.weapon_fired.disconnect(_on_player_weapon_fired)
		if _player_weapon_component.dry_fired.is_connected(_on_player_weapon_dry_fired):
			_player_weapon_component.dry_fired.disconnect(_on_player_weapon_dry_fired)
	_player_weapon_component = next_weapon
	if _player_weapon_component != null:
		if not _player_weapon_component.weapon_fired.is_connected(_on_player_weapon_fired):
			_player_weapon_component.weapon_fired.connect(_on_player_weapon_fired)
		if not _player_weapon_component.dry_fired.is_connected(_on_player_weapon_dry_fired):
			_player_weapon_component.dry_fired.connect(_on_player_weapon_dry_fired)

	var next_health := player.get_node_or_null("ActorHealthComponent") as ActorHealthComponent if player else null
	if _player_health_component != null and _player_health_component != next_health:
		if _player_health_component.damaged.is_connected(_on_player_damaged):
			_player_health_component.damaged.disconnect(_on_player_damaged)
		if _player_health_component.health_changed.is_connected(_on_player_health_changed):
			_player_health_component.health_changed.disconnect(_on_player_health_changed)
	_player_health_component = next_health
	if _player_health_component != null:
		if not _player_health_component.damaged.is_connected(_on_player_damaged):
			_player_health_component.damaged.connect(_on_player_damaged)
		if not _player_health_component.health_changed.is_connected(_on_player_health_changed):
			_player_health_component.health_changed.connect(_on_player_health_changed)


func _show_combat_feedback(text: String, color: Color) -> void:
	if combat_feedback:
		combat_feedback.text = text
		combat_feedback.modulate = color
		combat_feedback.visible = true
	if crosshair:
		crosshair.modulate = color
	_combat_feedback_timer = COMBAT_FEEDBACK_DURATION


func _on_player_weapon_fired(hit: bool, _hit_position: Vector3, _ammo_in_mag: int, _ammo_reserve: int) -> void:
	if hit:
		_show_combat_feedback("HIT", CROSSHAIR_HIT_COLOR)
	else:
		_show_combat_feedback("MISS", CROSSHAIR_DEFAULT_COLOR)


func _on_player_weapon_dry_fired(_ammo_in_mag: int, _ammo_reserve: int) -> void:
	_show_combat_feedback("EMPTY", Color(1, 0.85, 0.4, 1))


func _on_player_damaged(amount: float, _source: Node) -> void:
	if amount <= 0.0:
		return
	_damage_flash_alpha = minf(0.75, _damage_flash_alpha + 0.3)
	_show_combat_feedback("-%d HP" % int(round(amount)), Color(1, 0.45, 0.4, 1))


func _on_player_health_changed(current_health: float, max_health: float) -> void:
	if health_readout:
		health_readout.text = "HP %d/%d" % [int(round(current_health)), int(round(max_health))]


func _update_health_readout() -> void:
	if health_readout == null:
		return
	if _player_health_component == null:
		health_readout.text = "HP --"
		return
	_on_player_health_changed(_player_health_component.current_health, _player_health_component.max_health)


func _warn_if_player_missing() -> void:
	# Missing player is not fatal, but interaction hint updates are intentionally disabled.
	if player == null:
		push_warning("GameUIController: player could not be resolved; interaction hint updates are disabled.")


func _handle_examine_request(request: PlayerInteractionRequest) -> void:
	var panel := modal_state.get_registered_panel(MODAL_EXAMINE) as ExaminePanel
	# Ignore examine interaction when the modal is not part of this scene.
	if panel == null:
		return
	panel.show_content(str(request.payload.get("title", "")), str(request.payload.get("content", "")))
	modal_state.open(MODAL_EXAMINE)
	# Examine modal owns focus, so world hint should disappear while open.
	if interact_hint:
		interact_hint.visible = false


func _handle_dialogue_request(request: PlayerInteractionRequest) -> void:
	var conversation := request.payload.get("conversation") as DialogueConversation
	# If no authored conversation is supplied, synthesize a one-line conversation payload.
	if conversation == null:
		conversation = _create_single_line_dialogue(request.payload)
	var context := DialogueContext.new(request.initiating_actor, request.interactable, _dialogue_state)
	var panel := modal_state.get_registered_panel(MODAL_DIALOGUE) as DialoguePanel
	# Dialogue request becomes a no-op when dialogue panel is absent in current scene.
	if panel == null:
		return
	# Open modal only after panel accepts the conversation payload.
	if panel.open_dialogue(conversation, context):
		modal_state.open(MODAL_DIALOGUE)
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


# Kept for existing scene signal connection; closes via the unified panel callback.
func _on_examine_close_pressed() -> void:
	var panel := modal_state.get_registered_panel(MODAL_EXAMINE)
	# Legacy signal path closes through panel API to keep one close flow.
	if panel:
		panel.close_panel()


func _on_intro_continue_pressed() -> void:
	can_pause = true
	modal_state.close(MODAL_INTRO)


func _on_resume_pressed() -> void:
	_resume_game()


func _on_quit_to_menu_pressed() -> void:
	modal_state.release_for_exit()
	quit_to_menu_requested.emit()


func _on_quit_game_pressed() -> void:
	modal_state.release_for_exit()
	quit_game_requested.emit()


func _open_pause_menu() -> void:
	modal_state.open(MODAL_PAUSE)
	# Pause modal blocks interaction prompt while active.
	if interact_hint:
		interact_hint.visible = false


func _resume_game() -> void:
	modal_state.close(MODAL_PAUSE)
	_refresh_interact_hint()


func _on_inventory_opened() -> void:
	modal_state.open(MODAL_INVENTORY)
	# Opening inventory may invalidate current hint visibility/state.
	if interact_hint:
		interact_hint.visible = false
	_refresh_interact_hint()


func _handle_scrapping_request(request: PlayerInteractionRequest) -> void:
	var inventory_holder := InventoryHolderComponent.find_on(request.initiating_actor)
	# Scrapping needs an inventory source; abort gracefully for actors without one.
	if inventory_holder == null or inventory_holder.inventory == null:
		return
	var panel := modal_state.get_registered_panel(MODAL_SCRAPPING) as ScrappingPanel
	# No registered panel means this interaction type is unavailable in this scene.
	if panel == null:
		return
	panel.show_inventory(inventory_holder.inventory)
	modal_state.open(MODAL_SCRAPPING)
	# Scrapping UI now owns focus, so world interaction hint is hidden.
	if interact_hint:
		interact_hint.visible = false


func _on_panel_closed(modal_id: StringName) -> void:
	modal_state.close(modal_id)
	_refresh_interact_hint()


func _refresh_interact_hint() -> void:
	# Player can be absent in test harness scenes or during teardown.
	if player == null:
		return
	_on_interactable_changed(player.get_current_interactable())
