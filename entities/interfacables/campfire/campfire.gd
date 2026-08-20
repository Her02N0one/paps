@tool
class_name Campfire
extends StaticBody3D

@onready var interactable := $Interactable as Interactable

func _ready() -> void:
	if not Engine.is_editor_hint():
		if interactable:
			interactable.interact.connect(_on_interact)

func _on_interact(_actor: Node3D) -> void:
	var tm = get_node("/root/TimeManager") as TimeManager
	tm.skip_time(60.0) # Skip 1 hour
