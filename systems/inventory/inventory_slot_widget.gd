## Button-based slot presenter used by inventory and scrapping grids.
class_name InventorySlotWidget
extends Button

signal selected(slot_id: int)

const FALLBACK_ICON := preload("res://icon.png")

var slot_id := -1


func bind(slot: InventorySlot) -> void:
	# Stores only snapshot data; the panel resolves live slot state on interaction.
	slot_id = slot.id
	text = "%s\nx%d" % [slot.data.display_name, slot.quantity]
	icon = slot.data.icon if slot.data.icon else FALLBACK_ICON
	tooltip_text = slot.data.description


func set_selected(value: bool) -> void:
	button_pressed = value


func _on_pressed() -> void:
	# Emit slot id rather than direct data so parent can fetch current authoritative slot.
	selected.emit(slot_id)
