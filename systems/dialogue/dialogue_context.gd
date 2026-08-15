## Gameplay references available to dialogue conditions and effects.
## Keeping these dependencies here lets authored dialogue remain plain Resources.
class_name DialogueContext
extends RefCounted

var actor: Node3D
var source: Interactable
var state: Node


func _init(requesting_actor: Node3D, interaction_source: Interactable, game_state: Node) -> void:
	actor = requesting_actor
	source = interaction_source
	state = game_state


## Reads a persistent game-state flag, returning the default when state is unavailable.
func get_flag(flag: StringName, default_value: Variant = null) -> Variant:
	if state == null or not state.has_method("get_global_flag"):
		return default_value
	return state.get_global_flag(flag, default_value)


## Writes a persistent game-state flag when the supplied state service supports it.
func set_flag(flag: StringName, value: Variant) -> void:
	if state and state.has_method("set_global_flag"):
		state.set_global_flag(flag, value)