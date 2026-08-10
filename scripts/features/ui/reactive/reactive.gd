## Base reactive primitive with optional parent-owner propagation.
class_name Reactive
extends Resource

signal reactive_changed

var reactive_owner: Reactive:
	set(value):
		if reactive_owner == value:
			return
		# Rebind owner callback so nested reactive changes bubble upward once.
		if reactive_owner and reactive_changed.is_connected(Callable(reactive_owner, "_on_reactive_child_changed")):
			reactive_changed.disconnect(Callable(reactive_owner, "_on_reactive_child_changed"))
		reactive_owner = value
		if reactive_owner and not reactive_changed.is_connected(Callable(reactive_owner, "_on_reactive_child_changed")):
			reactive_changed.connect(Callable(reactive_owner, "_on_reactive_child_changed"))


func notify_reactive_changed() -> void:
	reactive_changed.emit()


func _on_reactive_child_changed() -> void:
	notify_reactive_changed()
