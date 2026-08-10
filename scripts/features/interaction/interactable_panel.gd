## Interactable variant that requests an examine modal with authored panel content.
class_name InteractablePanel
extends Interactable

@export var panel_title: String = "Panel"
@export_multiline var content: String = ""

func _ready() -> void:
	super()
	interact_label = "Examine " + panel_title


func activate(actor: Node3D) -> void:
	# Payload is interpreted by GameUIController's examine handler.
	request_player_interaction(PlayerInteractionRequest.EXAMINE, actor, {
		"title": panel_title,
		"content": content,
	})
