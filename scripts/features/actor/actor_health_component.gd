## Shared health state for any actor-like entity.
class_name ActorHealthComponent
extends Node

signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal defeated(source: Node)
signal revived

@export var max_health := 100.0
@export var current_health := 100.0


func _ready() -> void:
	max_health = maxf(max_health, 1.0)
	current_health = clampf(current_health, 0.0, max_health)


func set_max_health(value: float, refill := false) -> void:
	max_health = maxf(value, 1.0)
	if refill:
		current_health = max_health
	else:
		current_health = minf(current_health, max_health)
	health_changed.emit(current_health, max_health)


func apply_damage(amount: float, source: Node = null) -> float:
	var applied := clampf(amount, 0.0, current_health)
	if is_zero_approx(applied):
		return 0.0
	current_health -= applied
	damaged.emit(applied, source)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		defeated.emit(source)
	return applied


func heal(amount: float) -> float:
	var missing := maxf(max_health - current_health, 0.0)
	var applied := clampf(amount, 0.0, missing)
	if is_zero_approx(applied):
		return 0.0
	var was_defeated := current_health <= 0.0
	current_health += applied
	healed.emit(applied)
	health_changed.emit(current_health, max_health)
	if was_defeated and current_health > 0.0:
		revived.emit()
	return applied


func is_alive() -> bool:
	return current_health > 0.0


func get_health_fraction() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(current_health / max_health, 0.0, 1.0)
