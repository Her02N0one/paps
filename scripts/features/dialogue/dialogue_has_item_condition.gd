## Dialogue condition that checks item quantity on the interacting actor.
class_name DialogueHasItemCondition
extends DialogueCondition

@export var item: ItemData
@export var quantity := 1


func is_met(context: DialogueContext) -> bool:
	var holder := InventoryHolderComponent.find_on(context.actor)
	# Condition fails cleanly when no inventory holder exists on the actor.
	return holder != null and holder.inventory.has_item(item, quantity)
