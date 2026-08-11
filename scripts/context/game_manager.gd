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

enum _FadeState { IDLE, OUT, IN }
var _fade_state := _FadeState.IDLE
var _fade_elapsed := 0.0
const _FADE_DURATION := 0.5
const NEW_GAME_ENTRY_PREFIX := "__new_game_entry__:"
var _pending_fade_completion_action: Callable
var _save_manager: SaveManager
var _game_state: GameState
var _show_world_context_fn: Callable
var _show_main_menu_context_fn: Callable


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


func set_scene_switchers(show_world_context: Callable, show_main_menu_context: Callable) -> void:
	set_context_switch_callbacks(show_world_context, show_main_menu_context)


func _update_fade_size() -> void:
	_fade_rect.position = Vector2.ZERO
	_fade_rect.size = get_tree().root.get_visible_rect().size


func _process(delta: float) -> void:
	# Fade state is a tiny state machine; callback execution happens only once at full black.
	match _fade_state:
		_FadeState.OUT:
			_fade_elapsed += delta
			_fade_rect.modulate.a = clampf(_fade_elapsed / _FADE_DURATION, 0.0, 1.0)
			# Execute queued transition callback exactly once when fade-out completes.
			if _fade_elapsed >= _FADE_DURATION:
				_fade_rect.modulate.a = 1.0
				_fade_state = _FadeState.IDLE
				# Callback may be unset for pure fade operations.
				if _pending_fade_completion_action.is_valid():
					_pending_fade_completion_action.call()
					_pending_fade_completion_action = Callable()
		_FadeState.IN:
			_fade_elapsed += delta
			_fade_rect.modulate.a = clampf(1.0 - _fade_elapsed / _FADE_DURATION, 0.0, 1.0)
			# End fade-in and unlock transition gate.
			if _fade_elapsed >= _FADE_DURATION:
				_fade_rect.modulate.a = 0.0
				_fade_state = _FadeState.IDLE
				_is_transitioning = false


func _fade_out(on_complete: Callable) -> void:
	_fade_elapsed = 0.0
	_pending_fade_completion_action = on_complete
	_fade_state = _FadeState.OUT


func fade_in() -> void:
	_fade_elapsed = 0.0
	_fade_rect.modulate.a = 1.0
	_fade_state = _FadeState.IN


func start_new_game(initial_map: String, new_game_spawn_marker_id: StringName = &"") -> void:
	# Ignore re-entrant requests while another transition is mid-flight.
	if _is_transitioning or _save_manager == null:
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


func continue_game() -> void:
	# Continue requires both a loaded area path and an injected world-switch callback.
	if _is_transitioning or _game_state == null or _game_state.current_area.is_empty():
		return
	# Context switch callback must be injected by RootContext.
	if not _show_world_context_fn.is_valid():
		push_error("Cannot continue game: world context callback is not configured.")
		return
	_show_intro_on_world_start = false
	_start_world(_game_state.current_area)


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
	_fade_rect.modulate.a = 1.0
	_fade_state = _FadeState.IDLE
	# Pending map indicates a queued transition that still needs swap execution.
	if pending_target_map != "":
		_execute_swap(world)
	else:
		# No pending travel means we only need to reveal the current scene.
		fade_in()


func travel(target_map: String, spawn_id: String, reversed: bool = false) -> void:
	# Transition gate prevents overlapping travel requests.
	if _is_transitioning:
		return
	_is_transitioning = true
	# Persist before travel so map exit state is recoverable.
	if _save_manager:
		_save_manager.save_game()
	pending_target_map = target_map
	pending_target_spawn_id = spawn_id
	pending_entry_reversed = reversed
	# World lookup is deferred until black screen so map swap happens off-camera.
	_fade_out(func():
		var world := get_tree().get_first_node_in_group("world") as World
		_execute_swap(world)
	)


func quit_to_menu() -> void:
	# Transition gate prevents overlapping quit requests.
	if _is_transitioning:
		return
	# Menu callback must be injected by RootContext.
	if not _show_main_menu_context_fn.is_valid():
		push_error("Cannot quit to menu: main menu context callback is not configured.")
		return
	_is_transitioning = true
	# Persist before quitting world context.
	if _save_manager:
		_save_manager.save_game()
	pending_target_map = ""
	pending_target_spawn_id = ""
	_fade_out(func(): _show_main_menu_context_fn.call())


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
