class_name InventoryPanel
extends PanelContainer

signal opened
signal closed

const FALLBACK_ICON := preload("res://icon.png")

@export var slot_scene: PackedScene

@onready var summary_label: Label = %Summary
@onready var slot_grid: GridContainer = %SlotGrid
@onready var empty_label: Label = %EmptyLabel
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_name: Label = %DetailName
@onready var detail_description: Label = %DetailDescription
@onready var detail_quantity: Label = %DetailQuantity
@onready var use_button: Button = %UseButton
@onready var drop_button: Button = %DropButton
@onready var status_label: Label = %StatusLabel

var _selected_slot_id := -1
var _action_user: Node
var _slot_widgets: Array[InventorySlotWidget] = []


func _ready() -> void:
	var inventory := get_node("/root/Inventory")
	inventory.changed.connect(_refresh)
	_refresh(inventory.get_slots())


func set_action_user(user: Node) -> void:
	_action_user = user


func open_panel() -> void:
	if visible:
		return
	visible = true
	status_label.text = ""
	_refresh(get_node("/root/Inventory").get_slots())
	opened.emit()


func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func toggle_panel() -> void:
	if visible:
		close_panel()
	else:
		open_panel()


func _refresh(slots: Array[InventorySlot]) -> void:
	_clear_slots()
	var selected_slot: InventorySlot
	var total_items := 0
	for slot in slots:
		total_items += slot.quantity
		var widget: InventorySlotWidget = slot_scene.instantiate()
		widget.bind(slot)
		widget.selected.connect(_select_slot)
		slot_grid.add_child(widget)
		_slot_widgets.append(widget)
		if slot.id == _selected_slot_id:
			selected_slot = slot

	empty_label.visible = slots.is_empty()
	summary_label.text = "%d slots, %d items" % [slots.size(), total_items]
	if selected_slot == null and not slots.is_empty():
		selected_slot = slots[0]
		_selected_slot_id = selected_slot.id
	if slots.is_empty():
		_selected_slot_id = -1
	_show_details(selected_slot)


func _clear_slots() -> void:
	_slot_widgets.clear()
	for child in slot_grid.get_children():
		slot_grid.remove_child(child)
		child.queue_free()


func _select_slot(slot_id: int) -> void:
	_selected_slot_id = slot_id
	_show_details(get_node("/root/Inventory").get_slot(slot_id))
	status_label.text = ""


func _show_details(slot: InventorySlot) -> void:
	var has_selection := slot != null
	detail_icon.visible = has_selection
	detail_icon.texture = (slot.data.icon if slot.data.icon else FALLBACK_ICON) if has_selection else null
	detail_name.text = slot.data.display_name if has_selection else "No item selected"
	detail_description.text = slot.data.description if has_selection else "Select an inventory slot to view its details."
	detail_quantity.text = "Quantity: %d" % slot.quantity if has_selection else ""
	use_button.disabled = not has_selection or not slot.data.can_use(_action_user)
	drop_button.disabled = not has_selection or not slot.data.droppable
	for widget in _slot_widgets:
		widget.set_selected(has_selection and widget.slot_id == slot.id)


func _on_use_pressed() -> void:
	if get_node("/root/Inventory").use_slot(_selected_slot_id, _action_user):
		status_label.text = "Item used."
	else:
		status_label.text = "This item cannot be used here."


func _on_drop_pressed() -> void:
	if not get_node("/root/Inventory").drop_slot(_selected_slot_id):
		status_label.text = "This item cannot be dropped."


func _on_close_pressed() -> void:
	close_panel()
