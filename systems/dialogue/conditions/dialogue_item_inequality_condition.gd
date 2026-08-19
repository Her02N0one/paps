## Dialogue condition that checks item quantity on the interacting actor.
class_name DialogueItemInequalityCondition
extends DialogueCondition

@export var item: ItemDefinition
@export var anchor := 1
@export var inequality: String


func is_met(context: DialogueContext) -> bool:
	var holder := InventoryHolderComponent.find_on(context.actor)
	# Condition fails cleanly when no inventory holder exists on the actor.
	var quantity = holder.inventory.get_quantity(item)
	
	if inequality == ">":
		return quantity > anchor
	if inequality == ">=":
		return quantity >= anchor
	if inequality == "<":
		return quantity < anchor
	if inequality == "<=":
		return quantity <= anchor
	
	return false
	
