extends SceneTree

const SLOT_SCENE := preload("res://systems/inventory/inventory_slot.tscn")
const SCRAP := preload("res://systems/inventory/items/scrap.tres")
const OLD_COIN := preload("res://systems/inventory/items/old_coin.tres")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var panel := _create_panel()
	root.add_child(panel)

	var inventory := InventoryStore.new()
	root.add_child(inventory)
	inventory.add_item(OLD_COIN, 3)
	panel.open_panel(inventory)
	panel.quantity_input.value = 2
	panel._on_scrap_pressed()

	var converted := inventory.get_quantity(OLD_COIN) == 1 and inventory.get_quantity(SCRAP) == 2
	var accurate_status := panel.status_label.text == "Recovered 2 Scrap."
	if not converted or not accurate_status:
		push_error("Scrapping panel integration regression detected.")
		quit(1)
		return
	quit()


func _create_panel() -> ScrappingPanel:
	var panel := ScrappingPanel.new()
	panel.slot_scene = SLOT_SCENE
	panel.scrap_item = SCRAP
	_add_unique_control(panel, GridContainer.new(), "InputSlots")
	_add_unique_control(panel, Label.new(), "EmptyLabel")
	_add_unique_control(panel, Label.new(), "SelectedName")
	_add_unique_control(panel, TextureRect.new(), "SelectedIcon")
	_add_unique_control(panel, SpinBox.new(), "QuantityInput")
	_add_unique_control(panel, Label.new(), "YieldLabel")
	_add_unique_control(panel, TextureRect.new(), "OutputIcon")
	_add_unique_control(panel, Label.new(), "OutputLabel")
	_add_unique_control(panel, Button.new(), "ScrapButton")
	_add_unique_control(panel, Label.new(), "StatusLabel")
	var packed_panel := PackedScene.new()
	packed_panel.pack(panel)
	panel.free()
	return packed_panel.instantiate() as ScrappingPanel


func _add_unique_control(panel: ScrappingPanel, control: Control, control_name: String) -> void:
	control.name = control_name
	control.unique_name_in_owner = true
	panel.add_child(control)
	control.owner = panel