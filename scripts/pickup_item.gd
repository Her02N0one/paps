class_name PickupItem
extends StaticBody3D

@export var item_data: ItemData
@export var quantity: int = 1
@export var persistent_id: String = ""

@export var item_name: String = "Item"

var dynamic_id := ""

@onready var interaction: Interactable = $Interactable


func _ready() -> void:
	interaction.interact.connect(_on_interacted)
	if persistent_id.is_empty() and dynamic_id.is_empty():
		push_warning("Authored pickup '%s' has no persistent_id and will respawn when its area reloads." % name)
	if not persistent_id.is_empty() and GameState.is_static_pickup_collected(GameState.current_area, persistent_id):
		queue_free()
		return
	if item_data:
		interaction.interact_label = "Pick up " + item_data.display_name
	else:
		interaction.interact_label = "Pick up " + item_name


func _on_interacted(actor: Node3D) -> void:
	var inventory_holder := InventoryHolderComponent.find_on(actor)
	if item_data == null or inventory_holder == null or not inventory_holder.add_item(item_data, quantity):
		return
	if not dynamic_id.is_empty():
		GameState.remove_dynamic_pickup(GameState.current_area, dynamic_id)
	elif not persistent_id.is_empty():
		GameState.collect_static_pickup(GameState.current_area, persistent_id)
	SaveManager.save_game()
	queue_free()
