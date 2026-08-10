## Thin world-facing adapter between an NPC and an authored DialogueConversation.
## Character-specific dialogue logic belongs in resources, conditions, and effects.
class_name InteractablePerson
extends Interactable

@export var speaker_name := "Person"
@export_multiline var opening_text := "Hello."
@export var conversation: DialogueConversation

func _ready() -> void:
	super()
	interact_label = "Talk to " + speaker_name


func activate(actor: Node3D) -> void:
	var payload := {
		"speaker": speaker_name,
		"text": opening_text,
	}
	if conversation:
		payload["conversation"] = conversation
	request_player_interaction(PlayerInteractionRequest.DIALOGUE, actor, payload)
