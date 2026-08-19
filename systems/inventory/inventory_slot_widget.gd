## Button-based slot presenter used by inventory and scrapping grids.
class_name ItemStackWidget
extends Button

signal selected(slot_id: int)

const FALLBACK_ICON := preload("res://icon.png")

var slot_id := -1


func bind(slot: ItemStack) -> void:
	# Stores only snapshot data; the panel resolves live slot state on interaction.
	slot_id = slot.id
	text = "%s\nx%d" % [slot.definition.display_name, slot.quantity]
	icon = slot.definition.icon if slot.definition.icon else FALLBACK_ICON
	tooltip_text = slot.definition.description


func set_selected(value: bool) -> void:
	button_pressed = value


func _on_pressed() -> void:
	# Emit slot id rather than direct data so parent can fetch current authoritative slot.
	selected.emit(slot_id)
