@tool
## World search object: handles interaction label, persistence checks, and collection emit.
## Evaluates a LootTable to determine its contents.
class_name SearchObject
extends StaticBody3D

signal collected(persistent_id: String, dynamic_id: String)

@export var loot_table: LootTable
@export var persistent_id: String = ""

@export var object_name: String = "Object"
@export var lifespan: float = 0.0

var dynamic_id := ""
var _pending_loot: Array[ItemPayload] = []
var _has_rolled: bool = false

@onready var interaction := $Interactable as Interactable

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() and lifespan > 0.0:
		lifespan -= delta
		if lifespan <= 0.0:
			queue_free()


func _ready() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
	if interaction.has_signal("interact"):
		interaction.connect("interact", Callable(self, "_on_interacted"))
	if persistent_id.is_empty() and dynamic_id.is_empty():
		push_warning("Authored search object '%s' has no persistent_id and will respawn when its area reloads." % name)
			
	if not persistent_id.is_empty():
		var gs := ServiceRegistry.game_state
		# Static pickups self-prune when already marked collected in the current area.
		if gs and gs.is_static_pickup_collected(gs.current_area, persistent_id):
			queue_free()
			return
			
	if loot_table:
		interaction.set("interact_label", "Search " + object_name)
	else:
		interaction.set("interact_label", "Search " + object_name)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if get_node_or_null("Interactable") == null:
		warnings.append("SearchObject requires an Interactable child node.")
	if loot_table == null:
		warnings.append("SearchObject requires a loot_table.")
	if persistent_id.is_empty():
		warnings.append("SearchObject has no persistent_id and will always respawn after area reloads unless spawned as a dynamic object.")
	return warnings


func _on_interacted(actor: Node3D) -> void:
	var inventory_holder := InventoryHolderComponent.find_on(actor)
	if inventory_holder == null:
		return
		
	if not _has_rolled:
		_roll_loot()
		
	if _pending_loot.is_empty():
		# Empty roll or already looted
		collected.emit(persistent_id, dynamic_id)
		queue_free()
		return
		
	var remaining_loot: Array[ItemPayload] = []
	for payload in _pending_loot:
		var success := inventory_holder.add_item(payload.item_definition, payload.quantity_min)
		if not success:
			remaining_loot.append(payload)
			
	_pending_loot = remaining_loot
	
	if _pending_loot.is_empty():
		collected.emit(persistent_id, dynamic_id)
		queue_free()


func _roll_loot() -> void:
	_has_rolled = true
	
	if loot_table:
		var raw_loot := loot_table.generate_loot()
		for payload in raw_loot:
			if payload is ItemPayload and payload.item_definition:
				var qty := randi_range(payload.quantity_min, payload.quantity_max)
				if qty > 0:
					var actual_payload := payload.duplicate() as ItemPayload
					actual_payload.quantity_min = qty
					actual_payload.quantity_max = qty
					_pending_loot.append(actual_payload)
