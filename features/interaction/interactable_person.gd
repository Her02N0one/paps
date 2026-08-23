## Thin world-facing adapter between an NPC and authored dialogue.
class_name InteractablePerson
extends Interactable

var person_definition: PersonDefinition


func set_person_definition(value: PersonDefinition) -> void:
	person_definition = value
	_update_label()


func _ready() -> void:
	super()
	_update_label()


func _update_label() -> void:
	var name_to_use := person_definition.speaker_name if person_definition != null else ""
	interact_label = "Talk to " + name_to_use if not name_to_use.is_empty() else "Talk"


func activate(actor: Node3D) -> void:
	var payload := {
		"speaker": person_definition.speaker_name if person_definition != null else "",
		"person_definition": person_definition,
	}
	if person_definition != null and person_definition.get_conversation() != null:
		payload["conversation"] = person_definition.get_conversation()

	request_player_interaction(PlayerInteractionRequest.DIALOGUE, actor, payload)
