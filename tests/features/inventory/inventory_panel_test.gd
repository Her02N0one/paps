extends SceneTree

const PANEL_SCENE := preload("res://systems/inventory/inventory_panel.tscn")
const OLD_COIN := preload("res://systems/inventory/items/old_coin.tres")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var inventory := InventoryStore.new()
	inventory.add_item(OLD_COIN, 2)
	root.add_child(inventory)
	var panel := PANEL_SCENE.instantiate() as InventoryPanel
	root.add_child(panel)
	panel.bind_inventory(inventory)
	panel.open_panel()
	var initial_refresh := panel.summary_label.text == "1 slots, 2 items"
	inventory.add_item(OLD_COIN)
	var live_refresh := panel.summary_label.text == "1 slots, 3 items"

	if not initial_refresh or not live_refresh:
		push_error("Inventory panel binding regression detected.")
		quit(1)
		return
	quit()