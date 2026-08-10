@tool
class_name InteractionSensorComponent
extends Node

signal interactable_changed(interactable: Interactable)

@export var shape_cast: ShapeCast3D

var enabled := true
var _current_interactable: Interactable


func _ready() -> void:
	# Fallback to conventional child path when export was not assigned.
	if shape_cast == null:
		shape_cast = get_node_or_null("ShapeCast3D") as ShapeCast3D
	# Show wiring warnings inside editor to catch scene setup issues early.
	if Engine.is_editor_hint():
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	# Sensor cannot detect interactions without a shape cast source.
	if shape_cast == null:
		warnings.append("InteractionSensorComponent requires a ShapeCast3D reference (export or child named 'ShapeCast3D').")
	return warnings


func physics_tick() -> void:
	# Clear stale target when focused interactable was removed or invalidated.
	if _current_interactable != null and not _has_valid_target():
		_set_current_interactable(null)
		return
	var found := _find_interactable()
	# Emit target changes only when focus actually changed.
	if found != _current_interactable:
		_set_current_interactable(found)


func activate(actor: Node3D) -> bool:
	# Activation requires a still-valid target at the time of input.
	if not _has_valid_target():
		_set_current_interactable(null)
		return false
	var target := _current_interactable
	target.activate(actor)
	_set_current_interactable(null)
	return true


func get_current_interactable() -> Interactable:
	# Mirror runtime validity checks for callers that poll current target.
	if not _has_valid_target():
		_current_interactable = null
	return _current_interactable


func _find_interactable() -> Interactable:
	# Disabled sensor or missing cast source means no candidate search.
	if not enabled or shape_cast == null:
		return null
	shape_cast.force_shapecast_update()
	# No collisions means no interactables to evaluate this frame.
	if not shape_cast.is_colliding():
		return null
	var best_interactable: Interactable
	var best_ray_distance_squared := INF
	var best_forward_distance := INF
	var candidates: Dictionary = {}
	# Favor what is visually closest to the view ray, then use depth as a stable tie-breaker.
	for index in shape_cast.get_collision_count():
		var collider := shape_cast.get_collider(index)
		# Ignore freed/invalid collider references from physics query.
		if not is_instance_valid(collider):
			continue
		var interactable := Interactable.find_on(collider)
		# Skip null candidates and deduplicate repeated collider hits.
		if interactable == null or candidates.has(interactable):
			continue
		candidates[interactable] = true
		var distances := _get_view_ray_distances(interactable.get_visual_center())
		var ray_distance_squared: float = distances.x
		var forward_distance: float = distances.y
		if (
			ray_distance_squared < best_ray_distance_squared
			or is_equal_approx(ray_distance_squared, best_ray_distance_squared)
			and forward_distance < best_forward_distance
		):
			# Keep the candidate closest to view ray; use depth as deterministic tie-break.
			best_ray_distance_squared = ray_distance_squared
			best_forward_distance = forward_distance
			best_interactable = interactable
	return best_interactable


func _get_view_ray_distances(center: Vector3) -> Vector2:
	var offset := center - shape_cast.global_position
	var view_direction := -shape_cast.global_transform.basis.z.normalized()
	var forward_distance := maxf(offset.dot(view_direction), 0.0)
	var closest_point_on_ray := shape_cast.global_position + view_direction * forward_distance
	return Vector2(center.distance_squared_to(closest_point_on_ray), forward_distance)


func _has_valid_target() -> bool:
	return is_instance_valid(_current_interactable)


func _set_current_interactable(interactable: Interactable) -> void:
	# Avoid redundant signal/disconnect/reconnect churn for same target.
	if interactable == _current_interactable:
		return
	if is_instance_valid(_current_interactable):
		# Disconnect old one-shot callback before replacing focused target.
		if _current_interactable.tree_exiting.is_connected(_on_current_interactable_exiting):
			_current_interactable.tree_exiting.disconnect(_on_current_interactable_exiting)
		_current_interactable.unhighlight()
	_current_interactable = interactable
	if _current_interactable:
		# Targets can disappear independently (pickup, area unload), so clear focus as they leave the tree.
		_current_interactable.tree_exiting.connect(_on_current_interactable_exiting, CONNECT_ONE_SHOT)
		_current_interactable.highlight()
	interactable_changed.emit(_current_interactable)


func _on_current_interactable_exiting() -> void:
	# Target left scene tree; clear focus and notify listeners.
	_current_interactable = null
	interactable_changed.emit(null)
