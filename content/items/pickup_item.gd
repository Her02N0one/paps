
class_name PickupItem
extends RigidBody3D

signal collected(persistent_id: String, dynamic_id: String)

@export var persistent_id: String = ""
@export var lifespan: float = 0.0

var dynamic_id := ""
var instance: ItemInstance = null

@onready var interaction := $Interactable as Interactable

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() and lifespan > 0.0:
		lifespan -= delta
		if lifespan <= 0.0:
			queue_free()


func _ready() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
		
	if not has_node("CollisionShape3D") and not has_node("CollisionShape3d"):
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var shape := SphereShape3D.new()
		shape.radius = 0.24
		col.shape = shape
		add_child(col)
		
	if interaction.has_signal("interact"):
		interaction.connect("interact", Callable(self, "_on_interacted"))
	if persistent_id.is_empty() and dynamic_id.is_empty():
		push_warning("Authored pickup '%s' has no persistent_id and will respawn when its area reloads." % name)

	if not persistent_id.is_empty():
		var gs := ServiceRegistry.game_state
		if gs and gs.is_static_pickup_collected(gs.current_area, persistent_id):
			queue_free()
			return
			
	if instance and instance.definition:
		interaction.set("interact_label", "Pick up " + instance.definition.display_name)
	else:
		interaction.set("interact_label", "Pick up Item")


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if get_node_or_null("Interactable") == null:
		warnings.append("PickupItem requires an Interactable child node.")
	if persistent_id.is_empty():
		warnings.append("PickupItem has no persistent_id and will always respawn after area reloads unless spawned as a dynamic pickup.")
	return warnings


func _on_interacted(actor: Node3D) -> void:
	if not instance or not instance.definition:
		queue_free()
		return
		
	var inventory_holder := InventoryHolderComponent.find_on(actor)
	if inventory_holder == null:
		return
		
	inventory_holder.add_instance(instance)
	collected.emit(persistent_id, dynamic_id)
	queue_free()
