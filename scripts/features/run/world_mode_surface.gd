## Base run-surface node that stores last bound payload for display/logic.
class_name ContextSurface
extends Node

@export var context_id: StringName

var _last_payload: Dictionary = {}


func bind_context_payload(payload: Dictionary) -> void:
	# Duplicate prevents shared mutable payload references between host and surface.
	_last_payload = payload.duplicate(true)


func get_last_payload() -> Dictionary:
	return _last_payload.duplicate(true)
