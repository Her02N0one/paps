extends Node

var pending_map := ""
var pending_spawn_id := ""
var pending_reversed := false
var _is_transitioning := false
var _fade_rect: ColorRect

enum _FadeState { IDLE, OUT, IN }
var _fade_state := _FadeState.IDLE
var _fade_elapsed := 0.0
const _FADE_DURATION := 0.5
var _pending_action: Callable


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


func _update_fade_size() -> void:
	_fade_rect.position = Vector2.ZERO
	_fade_rect.size = get_tree().root.get_visible_rect().size


func _process(delta: float) -> void:
	match _fade_state:
		_FadeState.OUT:
			_fade_elapsed += delta
			_fade_rect.modulate.a = clampf(_fade_elapsed / _FADE_DURATION, 0.0, 1.0)
			if _fade_elapsed >= _FADE_DURATION:
				_fade_rect.modulate.a = 1.0
				_fade_state = _FadeState.IDLE
				if _pending_action.is_valid():
					_pending_action.call()
					_pending_action = Callable()
		_FadeState.IN:
			_fade_elapsed += delta
			_fade_rect.modulate.a = clampf(1.0 - _fade_elapsed / _FADE_DURATION, 0.0, 1.0)
			if _fade_elapsed >= _FADE_DURATION:
				_fade_rect.modulate.a = 0.0
				_fade_state = _FadeState.IDLE
				_is_transitioning = false


func _fade_out(on_complete: Callable) -> void:
	_fade_elapsed = 0.0
	_pending_action = on_complete
	_fade_state = _FadeState.OUT


func fade_in() -> void:
	_fade_elapsed = 0.0
	_fade_rect.modulate.a = 1.0
	_fade_state = _FadeState.IN


func start_game(initial_map: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	pending_map = initial_map
	pending_spawn_id = ""
	_fade_out(func(): get_tree().change_scene_to_file("res://scenes/world.tscn"))


# Called by world.gd._ready() so the initial map can be loaded and fade in triggered.
func on_world_ready(world: Node) -> void:
	_fade_rect.modulate.a = 1.0
	_fade_state = _FadeState.IDLE
	if pending_map != "":
		_execute_swap(world)
	else:
		fade_in()


# Swap the active map inside the persistent world scene.
func travel(target_map: String, spawn_id: String, reversed: bool = false) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	pending_map = target_map
	pending_spawn_id = spawn_id
	pending_reversed = reversed
	_fade_out(func():
		var world := get_tree().get_first_node_in_group("world")
		_execute_swap(world)
	)


func quit_to_menu() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	pending_map = ""
	pending_spawn_id = ""
	_fade_out(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))


func _execute_swap(world: Node) -> void:
	world.swap_map(pending_map, pending_spawn_id, pending_reversed)
	pending_map = ""
	pending_spawn_id = ""
	pending_reversed = false
	fade_in()
