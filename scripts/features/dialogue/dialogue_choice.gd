## A player response, its visibility requirements, destination, and consequences.
class_name DialogueChoice
extends Resource

@export var text := "Continue"
@export var next_node_id: StringName
@export var conditions: Array[DialogueCondition] = []
@export var effects: Array[DialogueEffect] = []


## Returns true only when every authored condition passes.
func is_available(context: DialogueContext) -> bool:
	# Conditions use AND semantics; choices without conditions are always available.
	for condition in conditions:
		if condition and not condition.is_met(context):
			return false
	return true


## Applies selection effects before the session enters the destination node.
func apply_effects(context: DialogueContext) -> void:
	for effect in effects:
		if effect:
			effect.apply(context)