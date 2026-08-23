## Dialogue effect that grants items to the interaction actor's inventory holder.
class_name DialogueGiveItemEffect
extends DialogueEffect

@export var item: ItemDefinition
@export var quantity := 1


func apply(context: DialogueContext) -> void:
	var holder := InventoryHolderComponent.find_on(context.actor)
	# Missing inventory holder is treated as a no-op to keep dialogue flow resilient.
	if holder:
		holder.add_item(item, quantity)
