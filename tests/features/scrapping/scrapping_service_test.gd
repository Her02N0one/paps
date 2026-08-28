extends SceneTree

const SCRAP := preload("res://content/items/presets/scrap.tres")
const OLD_COIN := preload("res://content/items/presets/old_coin.tres")


func _initialize() -> void:
	var inventory := InventoryStore.new()
	root.add_child(inventory)
	inventory.add_item(OLD_COIN, 3)
	var coin_slot := inventory.get_slots()[0]
	var converted := ScrappingService.scrap_slot(inventory, coin_slot.id, 2, SCRAP)
	var valid_result := converted and inventory.get_quantity(OLD_COIN) == 1 and inventory.get_quantity(SCRAP) == 2
	var scrap_slot = inventory.get_slots().filter(func(slot): return slot.instance.definition == SCRAP)[0]
	var refused_scrap := not ScrappingService.scrap_slot(inventory, scrap_slot.id, 1, SCRAP)
	if not valid_result or not refused_scrap:
		push_error("Scrapping service regression detected.")
		quit(1)
		return
	quit()
