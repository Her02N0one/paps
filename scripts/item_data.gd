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


func can_use(_user: Node) -> bool:
	return false


func use(_user: Node) -> bool:
	return false
