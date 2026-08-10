class_name SpawnPoint
extends Marker3D

## Leave empty to use this marker when no matching gateway is found.
@export var spawn_id: String = ""


func _ready() -> void:
	add_to_group("spawn_points")
