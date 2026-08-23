class_name DurabilityData
extends ItemDataComponent

@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var modifiers: Array[String] = []

func serialize() -> Dictionary:
	return {
		"max_health": max_health,
		"current_health": current_health,
		"modifiers": modifiers
	}

func deserialize(data: Dictionary) -> void:
	max_health = data.get("max_health", 100.0)
	current_health = data.get("current_health", 100.0)
	var mods = data.get("modifiers", [])
	modifiers.clear()
	for m in mods:
		modifiers.append(str(m))
