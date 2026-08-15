## Action-to-handler registry for decoupled player interaction dispatch.
class_name UIInteractionRouter
extends RefCounted

var _handlers: Dictionary[StringName, Callable] = {}


func register_route(action: StringName, handler: Callable) -> void:
	if action.is_empty() or not handler.is_valid():
		return
	_handlers[action] = handler


func unregister_route(action: StringName) -> void:
	if action.is_empty():
		return
	_handlers.erase(action)


func has_route(action: StringName) -> bool:
	return _handlers.has(action)


func dispatch(request: PlayerInteractionRequest) -> bool:
	if request == null:
		return false
	var handler := _handlers.get(request.action, Callable()) as Callable
	if not handler.is_valid():
		# Missing handler is non-fatal; caller decides whether to warn.
		return false
	handler.call(request)
	return true


func clear() -> void:
	_handlers.clear()


func get_registered_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	for action in _handlers.keys():
		actions.append(action)
	return actions
