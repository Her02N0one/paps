class_name InteractablePanel
extends Interactable

@export var panel_title: String = "Panel"
@export_multiline var content: String = ""

signal opened(panel: InteractablePanel)


func _ready() -> void:
	super()
	interact_label = "Examine " + panel_title


func interact(_player: Node3D) -> void:
	opened.emit(self)
