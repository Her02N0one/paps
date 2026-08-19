## A player response, its visibility requirements, destination, and consequences.
class_name DialogueChoice
extends Resource

@export var text := "Continue"
@export var next_node_id: StringName

@export var conditions: Array[DialogueCondition] = []
@export var effects: Array[DialogueEffect] = []

@export_group("Goto Conversation")
## Optional target conversation graph resource to jump to when selected.
@export var target_conversation: DialogueConversation
## Optional target conversation key in the speaker's named conversations map to jump to.
@export var target_conversation_id: StringName




## Returns true only when every authored condition passes.
func is_available(context: DialogueContext) -> bool:
	for condition in conditions:
		if condition and not condition.is_met(context): # does the check for condition need to be here?
			return false
	return true


## Applies selection effects before the session enters the destination node.
func apply_effects(context: DialogueContext) -> void:
	for effect in effects:
		if effect:
			effect.apply(context)
