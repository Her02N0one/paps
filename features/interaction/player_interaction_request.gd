class_name PlayerInteractionRequest
extends RefCounted

const EXAMINE := &"examine"
const DIALOGUE := &"dialogue"
const SCRAPPING := &"scrapping"

var action: StringName
var initiating_actor: Node3D
var interactable: Interactable
# Action-specific data consumed by the handler registered for `action`.
var payload: Dictionary


func _init(
	requested_action: StringName,
	requesting_actor: Node3D,
	interaction_source: Interactable,
	interaction_payload: Dictionary = {}
) -> void:
	action = requested_action
	initiating_actor = requesting_actor
	interactable = interaction_source
	payload = interaction_payload
