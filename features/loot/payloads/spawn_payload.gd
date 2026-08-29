class_name SpawnPayload
extends LootPayload
## A loot payload that spawns a node into the world.

@export var base_scene: PackedScene
@export var display_name: String = ""
## Can be a Mesh or a PackedScene. Will be injected into the base scene.
@export var injected_model: Resource 
@export var injected_table: Resource # Will be cast to LootTable
