class_name PickupItem
extends Interactable

@export var item_data: ItemData
@export var quantity: int = 1
@export var persistent_id: String = ""

# Fallback label used only when item_data is not assigned.
@export var item_name: String = "Item"

var dynamic_id := ""


func _ready() -> void:
	super()
	if persistent_id.is_empty() and dynamic_id.is_empty():
		push_warning("Authored pickup '%s' has no persistent_id and will respawn when its area reloads." % name)
	if not persistent_id.is_empty() and GameState.is_static_pickup_collected(GameState.current_area, persistent_id):
		queue_free()
		return
	if item_data:
		interact_label = "Pick up " + item_data.display_name
	else:
		interact_label = "Pick up " + item_name


func interact(_player: Node3D) -> void:
	if item_data:
		get_node("/root/Inventory").add_item(item_data, quantity)
		if not dynamic_id.is_empty():
			GameState.remove_dynamic_pickup(GameState.current_area, dynamic_id)
		elif not persistent_id.is_empty():
			GameState.collect_static_pickup(GameState.current_area, persistent_id)
		SaveManager.save_game()
		queue_free()
