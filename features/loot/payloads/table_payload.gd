class_name TablePayload
extends LootPayload
## A loot payload that routes to another loot table for further resolution.

@export var table_reference: Resource # Will be cast to LootTable
