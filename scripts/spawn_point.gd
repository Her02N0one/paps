extends Marker3D

## Must match the target_spawn_id set on the Gateway that leads here.
@export var spawn_id: String = ""


func _ready() -> void:
	add_to_group("spawn_points")
