@tool
## Inventory-driven scrapping UI that filters valid inputs and previews output before commit.
class_name ScrappingPanel
extends GamePanel

const FALLBACK_ICON := preload("res://icon.png")

@export var slot_scene: PackedScene
@export var scrap_item: ItemData

@onready var input_slots: GridContainer = %InputSlots
@onready var empty_label: Label = %EmptyLabel
@onready var selected_name: Label = %SelectedName
@onready var selected_icon: TextureRect = %SelectedIcon
@onready var quantity_input: SpinBox = %QuantityInput
@onready var yield_label: Label = %YieldLabel
@onready var output_icon: TextureRect = %OutputIcon
@onready var output_label: Label = %OutputLabel
@onready var scrap_button: Button = %ScrapButton
@onready var status_label: Label = %StatusLabel

var _inventory: InventoryStore
var _selected_slot_id := -1
var _slot_widgets: Array[InventorySlotWidget] = []
var _selected_slot := ReactiveValue.new()
var _status_message := ReactiveValue.new("")


func _ready() -> void:
	super._ready()
	_selected_slot.reactive_changed.connect(_on_selected_slot_changed)
	_status_message.reactive_changed.connect(_on_status_message_changed)
	_on_selected_slot_changed()
	_on_status_message_changed()


func show_inventory(inventory: InventoryStore) -> void:
	_bind_inventory(inventory)
	visible = true
	_status_message.value = ""
	_refresh(_inventory.get_slots() if _inventory else [])
	opened.emit()


func open_panel(inventory: InventoryStore) -> void:
	show_inventory(inventory)


func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _bind_inventory(inventory: InventoryStore) -> void:
	if _inventory == inventory:
		return
	if _inventory and _inventory.changed.is_connected(_refresh):
		_inventory.changed.disconnect(_refresh)
	_inventory = inventory
	if _inventory:
		_inventory.changed.connect(_refresh)


func _refresh(slots: Array[InventorySlot]) -> void:
	_clear_slots()
	var selected_slot: InventorySlot
	for slot in slots:
		# Only show slots that can produce scrap output under current rules.
		if not ScrappingService.can_scrap(slot, scrap_item):
			continue
		var widget: InventorySlotWidget = slot_scene.instantiate()
		widget.bind(slot)
		widget.selected.connect(_select_slot)
		input_slots.add_child(widget)
		_slot_widgets.append(widget)
		if slot.id == _selected_slot_id:
			selected_slot = slot
	empty_label.visible = _slot_widgets.is_empty()
	if selected_slot == null and not _slot_widgets.is_empty():
		# Keep UI usable by selecting the first remaining valid slot after refresh.
		selected_slot = _inventory.get_slot(_slot_widgets[0].slot_id)
		_selected_slot_id = selected_slot.id
	_selected_slot.value = selected_slot


func _clear_slots() -> void:
	_slot_widgets.clear()
	for child in input_slots.get_children():
		child.queue_free()


func _select_slot(slot_id: int) -> void:
	_selected_slot_id = slot_id
	_status_message.value = ""
	_selected_slot.value = _inventory.get_slot(slot_id) if _inventory else null


func _on_selected_slot_changed() -> void:
	_show_selection(_selected_slot.value as InventorySlot)


func _on_status_message_changed() -> void:
	status_label.text = str(_status_message.value)


func _show_selection(slot: InventorySlot) -> void:
	var has_selection := ScrappingService.can_scrap(slot, scrap_item)
	selected_name.text = slot.data.display_name if has_selection else "No scrappable item selected"
	selected_icon.texture = (slot.data.icon if slot.data.icon else FALLBACK_ICON) if has_selection else null
	selected_icon.visible = has_selection
	quantity_input.editable = has_selection
	quantity_input.max_value = slot.quantity if has_selection else 1
	quantity_input.value = clampi(int(quantity_input.value), 1, slot.quantity) if has_selection else 1
	for widget in _slot_widgets:
		# Reflect single active selection in the button grid.
		widget.set_selected(has_selection and widget.slot_id == slot.id)
	_update_preview()


func _update_preview() -> void:
	var slot := _selected_slot.value as InventorySlot
	var output_quantity := ScrappingService.get_output_quantity(slot, int(quantity_input.value))
	# Preview is valid only when the selected slot is scrappable and produces non-zero output.
	var has_output := ScrappingService.can_scrap(slot, scrap_item) and output_quantity > 0
	yield_label.text = "%d Scrap each" % slot.data.scrap_yield if has_output else "Select an item to dismantle"
	output_icon.texture = (scrap_item.icon if scrap_item.icon else FALLBACK_ICON) if has_output else null
	output_icon.visible = has_output
	output_label.text = "%d x %s" % [output_quantity, scrap_item.display_name] if has_output else "No output"
	scrap_button.disabled = not has_output


func _on_quantity_changed(_value: float) -> void:
	_update_preview()


func _on_scrap_pressed() -> void:
	if _inventory == null:
		return
	var quantity := int(quantity_input.value)
	var selected_slot := _inventory.get_slot(_selected_slot_id)
	var output_quantity := ScrappingService.get_output_quantity(selected_slot, quantity)
	if ScrappingService.scrap_slot(_inventory, _selected_slot_id, quantity, scrap_item):
		_status_message.value = "Recovered %d Scrap." % output_quantity
	else:
		_status_message.value = "That item can no longer be scrapped."


func _on_close_pressed() -> void:
	close_panel()
