class_name ItemPayload
extends LootPayload
## A loot payload that represents giving an item to the player.

@export var item_definition: ItemDefinition
@export var quantity_min: int = 1
@export var quantity_max: int = 1

