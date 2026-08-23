@tool
## Modal inventory presenter with snapshot-driven refresh and detail/action gating.
class_name InventoryPanel
extends GamePanel

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
var _inventory: InventoryStore
var _slot_widgets: Array[ItemStackWidget] = []


func open_panel() -> void:
	# Open is idempotent to avoid duplicate opened signals from repeated hotkeys.
	if visible:
		return
	visible = true
	status_label.text = ""
	_refresh(_inventory.get_slots() if _inventory else [])
	opened.emit()


func bind_inventory(inventory: InventoryStore) -> void:
	if _inventory == inventory:
		return
	# Rebind change listener when swapping stores (e.g., new runtime player/inventory context).
	if _inventory and _inventory.changed.is_connected(_refresh):
		_inventory.changed.disconnect(_refresh)
	_inventory = inventory
	if _inventory:
		_inventory.changed.connect(_refresh)
	_refresh(_inventory.get_slots() if _inventory else [])


func set_action_user(user: Node) -> void:
	_action_user = user


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


func _refresh(slots: Array[ItemStack]) -> void:
	_clear_slots()
	# Rebuild widgets from snapshots while preserving the selected slot whenever it still exists.
	var selected_slot: ItemStack
	var total_items := 0
	for slot in slots:
		total_items += slot.instance.quantity
		var widget: ItemStackWidget = slot_scene.instantiate()
		widget.bind(slot)
		widget.selected.connect(_select_slot)
		slot_grid.add_child(widget)
		_slot_widgets.append(widget)
		if slot.id == _selected_slot_id:
			selected_slot = slot

	empty_label.visible = slots.is_empty()
	summary_label.text = "%d slots, %d items" % [slots.size(), total_items]
	if selected_slot == null and not slots.is_empty():
		# Falling back to the first slot avoids leaving stale detail controls after removal or conversion.
		selected_slot = slots[0]
		_selected_slot_id = selected_slot.id
	if slots.is_empty():
		# Clear stale slot id so action buttons remain disabled with empty inventories.
		_selected_slot_id = -1
	_show_details(selected_slot)


func _clear_slots() -> void:
	_slot_widgets.clear()
	for child in slot_grid.get_children():
		slot_grid.remove_child(child)
		child.queue_free()


func _select_slot(slot_id: int) -> void:
	_selected_slot_id = slot_id
	status_label.text = ""
	# Resolve latest slot snapshot by id in case quantities changed since grid render.
	_show_details(_inventory.get_slot(slot_id) if _inventory else null)


func _show_details(slot: ItemStack) -> void:
	var has_selection := slot != null
	detail_icon.visible = has_selection
	detail_icon.texture = (slot.instance.definition.icon if slot.instance.definition.icon else FALLBACK_ICON) if has_selection else null
	detail_name.text = slot.instance.definition.display_name if has_selection else "No item selected"
	detail_description.text = slot.instance.definition.description if has_selection else "Select an inventory slot to view its details."
	detail_quantity.text = "Quantity: %d" % slot.instance.quantity if has_selection else ""
	# Actions are gated by both selection state and item capabilities.
	use_button.disabled = not has_selection or not slot.instance.definition.can_use(_action_user)
	drop_button.disabled = not has_selection or not slot.instance.definition.droppable
	for widget in _slot_widgets:
		widget.set_selected(has_selection and widget.slot_id == slot.id)


func _on_use_pressed() -> void:
	if _inventory and _inventory.use_slot(_selected_slot_id, _action_user):
		status_label.text = "Item used."
	else:
		status_label.text = "This item cannot be used here."


func _on_drop_pressed() -> void:
	if _inventory == null or not _inventory.drop_slot(_selected_slot_id):
		status_label.text = "This item cannot be dropped."


func _on_close_pressed() -> void:
	close_panel()
