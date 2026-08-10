## Reactive container for one value, including nested Reactive propagation.
class_name ReactiveValue
extends Reactive

var _nested_reactive: Reactive

var value: Variant:
	set(v):
		if value == v:
			return
		# Rewire nested subscriptions whenever the wrapped value identity changes.
		_disconnect_nested()
		value = v
		_connect_nested()
		notify_reactive_changed()


func _init(initial_value: Variant = null, initial_owner: Reactive = null) -> void:
	value = initial_value
	reactive_owner = initial_owner
	_connect_nested()


func _connect_nested() -> void:
	if not (value is Reactive):
		_nested_reactive = null
		return
	var nested: Reactive = value
	_nested_reactive = nested
	if not _nested_reactive.reactive_changed.is_connected(_on_nested_changed):
		_nested_reactive.reactive_changed.connect(_on_nested_changed)


func _disconnect_nested() -> void:
	if _nested_reactive and _nested_reactive.reactive_changed.is_connected(_on_nested_changed):
		_nested_reactive.reactive_changed.disconnect(_on_nested_changed)
	_nested_reactive = null


func _on_nested_changed() -> void:
	notify_reactive_changed()
