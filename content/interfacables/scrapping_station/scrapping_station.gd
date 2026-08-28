## Interactable adapter that requests opening the scrapping modal.
class_name ScrappingStation
extends Interactable

func _ready() -> void:
	super()
	interact_label = "Use scrapping bench"


func activate(actor: Node3D) -> void:
	request_player_interaction(PlayerInteractionRequest.SCRAPPING, actor)
