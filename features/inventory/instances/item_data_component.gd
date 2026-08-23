class_name ItemDataComponent
extends Resource

## Base class for dynamic item traits (NBT-style).

func serialize() -> Dictionary:
	return {}

func deserialize(data: Dictionary) -> void:
	pass

func duplicate_component() -> ItemDataComponent:
	var copy = get_script().new()
	copy.deserialize(self.serialize())
	return copy
