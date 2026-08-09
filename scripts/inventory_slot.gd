class_name InventorySlot
extends RefCounted

var id: int
var data: ItemData
var quantity: int


func _init(slot_id: int, item_data: ItemData, item_quantity: int) -> void:
	id = slot_id
	data = item_data
	quantity = item_quantity


func snapshot() -> InventorySlot:
	return InventorySlot.new(id, data, quantity)