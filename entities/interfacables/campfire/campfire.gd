@tool
class_name Campfire
extends StaticBody3D

@onready var interactable := $Interactable as Interactable

func _ready() -> void:
	if not Engine.is_editor_hint():
		if interactable:
			interactable.interact.connect(_on_interact)

func _on_interact(_actor: Node3D) -> void:
	var tm = get_node_or_null("/root/TimeManager")
	if tm and tm.has_method("skip_time"):
		tm.skip_time(480.0) # Skip 8 hours
