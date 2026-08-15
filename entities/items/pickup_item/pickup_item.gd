@tool
## World pickup actor: handles interaction label, persistence checks, and collection emit.
class_name PickupItem
extends StaticBody3D

signal collected(persistent_id: String, dynamic_id: String)

@export var item_data: ItemData
@export var quantity: int = 1
@export var persistent_id: String = ""

@export var item_name: String = "Item"

var dynamic_id := ""

@onready var interaction := get_node_or_null("Interactable")


func _ready() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
	if interaction == null:
		return
	if interaction.has_signal("interact"):
		interaction.connect("interact", Callable(self, "_on_interacted"))
	if persistent_id.is_empty() and dynamic_id.is_empty():
		push_warning("Authored pickup '%s' has no persistent_id and will respawn when its area reloads." % name)
	if not persistent_id.is_empty():
		var gs := get_tree().get_first_node_in_group("game_state") as GameState
		# Static pickups self-prune when already marked collected in the current area.
		if gs and gs.is_static_pickup_collected(gs.current_area, persistent_id):
			queue_free()
			return
	if item_data:
		interaction.set("interact_label", "Pick up " + item_data.display_name)
	else:
		interaction.set("interact_label", "Pick up " + item_name)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if get_node_or_null("Interactable") == null:
		warnings.append("PickupItem requires an Interactable child node.")
	if item_data == null and item_name.strip_edges().is_empty():
		warnings.append("PickupItem should provide item_data or a non-empty fallback item_name.")
	if persistent_id.is_empty():
		warnings.append("PickupItem has no persistent_id and will always respawn after area reloads unless spawned as a dynamic pickup.")
	return warnings


func _on_interacted(actor: Node3D) -> void:
	var inventory_holder := InventoryHolderComponent.find_on(actor)
	# Collection succeeds only when both item data and inventory target are valid.
	if item_data == null or inventory_holder == null or not inventory_holder.add_item(item_data, quantity):
		return
	collected.emit(persistent_id, dynamic_id)
	queue_free()
