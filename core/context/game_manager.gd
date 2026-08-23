## Coordinates fade transitions and high-level context switches between menu and world.
## Owns pending travel intent so world loading and fade timing stay deterministic.
class_name GameManager
extends Node

const NEW_GAME_ENTRY_ID := "__new_game_entry__"

var pending_target_map := ""
var pending_target_spawn_id := ""
var pending_entry_reversed := false
var _show_intro_on_world_start := false
var _is_transitioning := false
var _fade_rect: ColorRect
var _fade_tween: Tween

const _FADE_DURATION := 0.5
const NEW_GAME_ENTRY_PREFIX := "__new_game_entry__:"
var _save_manager
var _game_state: GameState
var _show_world_context_fn: Callable
var _show_main_menu_context_fn: Callable
## FIFO of transition requests deferred while a fade is already in flight.
var _pending_transitions: Array[Callable] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var canvas := CanvasLayer.new()
	canvas.layer = 128
	add_child(canvas)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 0.0
	canvas.add_child(_fade_rect)
	_update_fade_size()
	get_tree().root.size_changed.connect(_update_fade_size)


func configure(save_manager: SaveManager, game_state: GameState) -> void:
	_save_manager = save_manager
	_game_state = game_state


func set_context_switch_callbacks(show_world_context: Callable, show_main_menu_context: Callable) -> void:
	_show_world_context_fn = show_world_context
	_show_main_menu_context_fn = show_main_menu_context


func _update_fade_size() -> void:
	_fade_rect.position = Vector2.ZERO
	_fade_rect.size = get_tree().root.get_visible_rect().size


func _fade_out(on_complete: Callable) -> void:
	_start_fade(1.0, on_complete)


func fade_in() -> void:
	_start_fade(0.0, Callable(self, "_on_fade_in_complete"))


func _on_fade_in_complete() -> void:
	_is_transitioning = false
	_try_execute_next_transition_request()


func _start_fade(target_alpha: float, on_complete: Callable) -> void:
	# _fade_rect only exists once _ready() has run (e.g. tests construct GameManager without
	# adding it to the tree); create_tween() also requires being inside the tree either way.
	if _fade_rect == null or not is_inside_tree():
		return
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "modulate:a", target_alpha, _FADE_DURATION)
	if on_complete.is_valid():
		_fade_tween.tween_callback(on_complete)


func start_new_game(initial_map: String, new_game_spawn_marker_id: StringName = &"") -> void:
	_enqueue_transition_request(
		&"start_new_game",
		Callable(self, "_perform_start_new_game").bind(initial_map, new_game_spawn_marker_id)
	)


func continue_game() -> void:
	_enqueue_transition_request(
		&"continue_game",
		Callable(self, "_perform_continue_game")
	)


func consume_intro_request() -> bool:
	var show_intro := _show_intro_on_world_start
	_show_intro_on_world_start = false
	return show_intro


func _start_world(initial_map: String, new_game_spawn_marker_id: StringName = &"") -> void:
	# Capture intent before fade-out so callbacks consume one stable snapshot.
	_is_transitioning = true
	pending_target_map = initial_map
	pending_target_spawn_id = _build_new_game_entry_token(new_game_spawn_marker_id) if _show_intro_on_world_start else ""
	pending_entry_reversed = false
	_fade_out(func(): _show_world_context_fn.call(pending_target_map, pending_target_spawn_id, pending_entry_reversed))


func _build_new_game_entry_token(marker_id: StringName) -> String:
	if marker_id.is_empty():
		return NEW_GAME_ENTRY_ID
	return NEW_GAME_ENTRY_PREFIX + String(marker_id)


func on_world_ready(world: World) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null
	_fade_rect.modulate.a = 1.0
	# Pending map indicates a queued transition that still needs swap execution.
	if pending_target_map != "":
		_execute_swap(world)
	else:
		# No pending travel means we only need to reveal the current scene.
		fade_in()


func travel(target_map: String, spawn_id: String, reversed: bool = false) -> void:
	_enqueue_transition_request(
		&"travel",
		Callable(self, "_perform_travel").bind(target_map, spawn_id, reversed)
	)


func quit_to_menu() -> void:
	_enqueue_transition_request(
		&"quit_to_menu",
		Callable(self, "_perform_quit_to_menu")
	)


func _perform_start_new_game(initial_map: String, new_game_spawn_marker_id: StringName) -> void:
	if _save_manager == null:
		return
	# Context switch callback must be injected by RootContext.
	if not _show_world_context_fn.is_valid():
		push_error("Cannot start a new game: world context callback is not configured.")
		return
	# Abort transition if save initialization failed.
	if not _save_manager.start_new_game(initial_map):
		return
	_show_intro_on_world_start = true
	_start_world(initial_map, new_game_spawn_marker_id)


func _perform_continue_game() -> void:
	# Continue requires both a loaded area path and an injected world-switch callback.
	if _game_state == null or _game_state.current_area.is_empty():
		return
	# Context switch callback must be injected by RootContext.
	if not _show_world_context_fn.is_valid():
		push_error("Cannot continue game: world context callback is not configured.")
		return
	_show_intro_on_world_start = false
	_start_world(_game_state.current_area)


func _perform_travel(target_map: String, spawn_id: String, reversed: bool) -> void:
	_is_transitioning = true
	pending_target_map = target_map
	pending_target_spawn_id = spawn_id
	pending_entry_reversed = reversed
	# World lookup is deferred until black screen so map swap happens off-camera.
	_fade_out(func():
		var world := get_tree().get_first_node_in_group("world") as World
		_execute_swap(world)
	)


func _perform_quit_to_menu() -> void:
	# Menu callback must be injected by RootContext.
	if not _show_main_menu_context_fn.is_valid():
		push_error("Cannot quit to menu: main menu context callback is not configured.")
		return
	_is_transitioning = true
	# Persist before quitting world context.
	if _save_manager:
		_save_manager.save_game("auto")
	pending_target_map = ""
	pending_target_spawn_id = ""
	_fade_out(func(): _show_main_menu_context_fn.call())


func _enqueue_transition_request(_label: StringName, action: Callable) -> void:
	if not action.is_valid():
		return
	_pending_transitions.append(action)
	_try_execute_next_transition_request()


func _try_execute_next_transition_request() -> void:
	while not _is_transitioning and not _pending_transitions.is_empty():
		var action: Callable = _pending_transitions.pop_front()
		action.call()


func _execute_swap(world: World) -> void:
	# Always clear pending state and restore visibility, even on failures.
	# Missing world coordinator is fatal for swap, but we still recover fade state.
	if world == null:
		push_error("Cannot load level because the world coordinator is unavailable.")
		_clear_pending_travel()
		fade_in()
		return
	# world.swap_map() can reject invalid scene path/spawn combinations.
	if not world.swap_map(pending_target_map, pending_target_spawn_id, pending_entry_reversed):
		push_error("World rejected level scene: %s" % pending_target_map)
	_clear_pending_travel()
	fade_in()


func _clear_pending_travel() -> void:
	pending_target_map = ""
	pending_target_spawn_id = ""
	pending_entry_reversed = false
