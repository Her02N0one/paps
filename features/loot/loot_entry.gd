class_name LootEntry
extends Resource
## A single weighted entry in a loot pool.

@export var weight: int = 100
@export var payload: LootPayload # Can be null to represent an empty roll (nothing dropped)
