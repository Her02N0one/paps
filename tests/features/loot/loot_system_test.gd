extends SceneTree
## A simple test to verify the LootTable's generate_loot logic.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Create dummy resources
	var dummy_item = ItemDefinition.new()
	var payload1 = ItemPayload.new()
	payload1.item_definition = dummy_item
	payload1.quantity_min = 2
	payload1.quantity_max = 2
	
	var payload2 = SpawnPayload.new()
	
	var entry1 = LootEntry.new()
	entry1.weight = 100
	entry1.payload = payload1
	
	var entry2 = LootEntry.new()
	entry2.weight = 0
	entry2.payload = payload2
	
	var pool1 = LootPool.new()
	pool1.rolls_min = 2
	pool1.rolls_max = 2
	pool1.entries = [entry1, entry2]
	
	var table1 = LootTable.new()
	table1.pools = [pool1]
	
	# Test basic rolling (should always roll entry1 twice, yielding 2 ItemPayloads)
	var results = table1.generate_loot()
	if results.size() != 2:
		push_error("Loot table failed to generate exact rolls.")
		quit(1)
		return
		
	if not results[0] is ItemPayload or results[0].quantity_max != 2:
		push_error("Loot table generated wrong payload.")
		quit(1)
		return
		
	# Test nested tables
	var table_payload = TablePayload.new()
	table_payload.table_reference = table1
	
	var nested_entry = LootEntry.new()
	nested_entry.weight = 100
	nested_entry.payload = table_payload
	
	var pool2 = LootPool.new()
	pool2.rolls_min = 1
	pool2.rolls_max = 1
	pool2.entries = [nested_entry]
	
	var table2 = LootTable.new()
	table2.pools = [pool2]
	
	var nested_results = table2.generate_loot()
	
	# nested_results should be identical to results
	if nested_results.size() != 2 or not nested_results[0] is ItemPayload:
		push_error("Loot table failed to flatten nested tables.")
		quit(1)
		return

	print("Loot system tests passed.")
	quit(0)
