class_name LootTable
extends Resource
## A collection of loot pools used to generate random items or spawns.

@export var pools: Array[LootPool] = []


## Rolls the table and recursively resolves nested tables, returning a flat list of payloads.
func generate_loot(rng: RandomNumberGenerator = null) -> Array[LootPayload]:
	var results: Array[LootPayload] = []
	for pool in pools:
		if not pool or pool.entries.is_empty():
			continue
		
		var num_rolls = rng.randi_range(pool.rolls_min, pool.rolls_max) if rng else randi_range(pool.rolls_min, pool.rolls_max)
		var total_weight = 0
		for entry in pool.entries:
			if entry:
				total_weight += entry.weight
		
		if total_weight <= 0:
			continue
			
		for i in range(num_rolls):
			var roll = rng.randi_range(1, total_weight) if rng else randi_range(1, total_weight)
			var current_weight = 0
			var selected_entry: LootEntry = null
			
			for entry in pool.entries:
				if entry:
					current_weight += entry.weight
					if roll <= current_weight:
						selected_entry = entry
						break
			
			if selected_entry and selected_entry.payload:
				_resolve_payload(selected_entry.payload, results, rng)
				
	return results


func _resolve_payload(payload: LootPayload, results: Array[LootPayload], rng: RandomNumberGenerator) -> void:
	if payload is TablePayload:
		if payload.table_reference and payload.table_reference is LootTable:
			results.append_array(payload.table_reference.generate_loot(rng))
		else:
			push_warning("TablePayload missing valid table_reference.")
	else:
		results.append(payload)
