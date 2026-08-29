@tool
## Simple modal surface for read-only examine text content.
class_name ExaminePanel
extends GamePanel

@export var _title: Label
@export var _content: Label


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint(): return
	var bus = get_node_or_null("/root/MessageBus")
	if bus and bus.has_signal("interaction_requested") and not bus.interaction_requested.is_connected(_on_interaction_requested):
		bus.interaction_requested.connect(_on_interaction_requested)


func _on_interaction_requested(request: PlayerInteractionRequest) -> void:
	if request.action == PlayerInteractionRequest.EXAMINE:
		_title.text = str(request.payload.get("title", ""))
		_content.text = str(request.payload.get("content", ""))
		
		var ui = get_tree().get_first_node_in_group(ModalManager.GROUP_WORLD_UI_CONTROLLER)
		if ui and ui.has_method("open"):
			ui.open(modal_id)



func _on_close_pressed() -> void:
	close_panel()
