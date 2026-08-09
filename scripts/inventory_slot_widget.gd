class_name InventorySlotWidget
extends Button

signal selected(slot_id: int)

const FALLBACK_ICON := preload("res://icon.png")

var slot_id := -1


func bind(slot: InventorySlot) -> void:
	slot_id = slot.id
	text = "%s\nx%d" % [slot.data.display_name, slot.quantity]
	icon = slot.data.icon if slot.data.icon else FALLBACK_ICON
	tooltip_text = slot.data.description


func set_selected(value: bool) -> void:
	button_pressed = value


func _on_pressed() -> void:
	selected.emit(slot_id)
