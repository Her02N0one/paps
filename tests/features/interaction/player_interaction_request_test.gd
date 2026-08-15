extends SceneTree


func _initialize() -> void:
	var actor := Node3D.new()
	var panel := InteractablePanel.new()
	panel.panel_title = "Notice"
	panel.content = "Keep out."
	var station := ScrappingStation.new()
	var person := InteractablePerson.new()
	var person_def := PersonDefinition.new()
	person_def.speaker_name = "Mara"
	person.person_definition = person_def

	var requests: Array = []
	for interactable in [panel, station, person]:
		interactable.player_interaction_requested.connect(func(request): requests.append(request))
		interactable.activate(actor)

	var valid: bool = (
		requests.size() == 3
		and requests[0].action == PlayerInteractionRequest.EXAMINE
		and requests[0].payload.get("title") == "Notice"
		and requests[1].action == PlayerInteractionRequest.SCRAPPING
		and requests[1].initiating_actor == actor
		and requests[2].action == PlayerInteractionRequest.DIALOGUE
		and requests[2].payload.get("speaker") == "Mara"
	)
	if not valid:
		push_error("Player interaction request protocol regression detected.")
		quit(1)
		return
	quit()