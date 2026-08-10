## Authoring resource for item metadata and optional use behavior hooks.
class_name ItemData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Item"
@export var description: String = ""
@export var icon: Texture2D = null
@export var stackable: bool = false
@export var max_stack: int = 1
@export var consumed_on_use: bool = false
@export var droppable: bool = true
@export_range(0, 999, 1) var scrap_yield: int = 0


func can_use(_user: Node) -> bool:
	# Override in derived item resources/scripts when the item has runtime behavior.
	return false


func use(_user: Node) -> bool:
	return false
