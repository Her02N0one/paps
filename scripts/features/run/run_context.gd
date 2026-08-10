@tool
## Hosts run-surface contexts (map and future surfaces) and mediates swap requests/results.
class_name RunContext
extends Node

signal context_opened(context_id: StringName, context_node: Node)
signal context_closed(context_id: StringName)
signal map_swap_requested(scene_path: String, spawn_id: String, reversed: bool)
signal gateway_travel_requested(target_scene: String, gateway_id: String, reversed: bool)
signal map_swap_completed(success: bool, area_path: String)

const CONTEXT_NONE := &""
const CONTEXT_MAP := &"map"

@export var map_context_scene: PackedScene

var _registered_context_scenes: Dictionary[StringName, PackedScene] = {}
var _active_context_id: StringName = CONTEXT_NONE
var _active_context_node: Node
var _current_area_path := ""
var _last_map_swap_success := false

@onready var _context_host: Node = $ContextHost


func _ready() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
	_register_default_context_scenes()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if map_context_scene == null:
		warnings.append("RunContext requires map_context_scene to be assigned.")
	if get_node_or_null("ContextHost") == null:
		warnings.append("RunContext requires a ContextHost child node.")
	return warnings


func register_context_scene(context_id: StringName, scene: PackedScene) -> void:
	if context_id == CONTEXT_NONE or scene == null:
		return
	_registered_context_scenes[context_id] = scene


func open_context(context_id: StringName, payload: Dictionary = {}) -> bool:
	if not _registered_context_scenes.has(context_id):
		push_warning("RunContext has no scene registered for context '%s'." % context_id)
		return false
	_close_active_context_internal()
	var scene: PackedScene = _registered_context_scenes[context_id]
	var context_node := scene.instantiate()
	_context_host.add_child(context_node)
	var resolved_payload: Dictionary = payload.duplicate(true)
	# Reopening map context after a successful swap should preserve the last known area payload.
	if context_id == CONTEXT_MAP and resolved_payload.is_empty() and _current_area_path != "":
		resolved_payload["area_path"] = _current_area_path
	if context_node.has_method("bind_context_payload"):
		context_node.call("bind_context_payload", resolved_payload)
	_active_context_id = context_id
	_active_context_node = context_node
	context_opened.emit(_active_context_id, _active_context_node)
	return true


func request_map_swap(scene_path: String, spawn_id: String = "", reversed: bool = false) -> bool:
	# Callers expect a boolean result after listeners process this signal synchronously.
	_last_map_swap_success = false
	map_swap_requested.emit(scene_path, spawn_id, reversed)
	return _last_map_swap_success


func report_map_swap_result(success: bool, area_path: String = "") -> void:
	_last_map_swap_success = success
	if success:
		# Keep context payload aligned with the world host's committed area.
		_current_area_path = area_path
		open_context(CONTEXT_MAP, {"area_path": area_path})
	map_swap_completed.emit(success, area_path)


func request_gateway_travel(target_scene: String, gateway_id: String, reversed: bool) -> void:
	gateway_travel_requested.emit(target_scene, gateway_id, reversed)


func close_active_context() -> void:
	_close_active_context_internal()


func get_active_context_id() -> StringName:
	return _active_context_id


func get_active_context_node() -> Node:
	return _active_context_node


func get_current_area_path() -> String:
	return _current_area_path


func _register_default_context_scenes() -> void:
	register_context_scene(CONTEXT_MAP, map_context_scene)


func _close_active_context_internal() -> void:
	# Contexts are always single-active; opening a new one first closes the previous instance.
	if is_instance_valid(_active_context_node):
		_active_context_node.queue_free()
		context_closed.emit(_active_context_id)
	_active_context_node = null
	_active_context_id = CONTEXT_NONE
