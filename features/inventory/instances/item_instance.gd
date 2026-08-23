class_name ItemInstance
extends RefCounted

## A dynamic wrapper for an ItemDefinition that holds runtime components (NBT-style).

var definition: ItemDefinition
var quantity: int = 1
var components: Dictionary = {} # String -> ItemDataComponent

func _init(p_def: ItemDefinition = null, p_quantity: int = 1) -> void:
	definition = p_def
	quantity = p_quantity

func add_component(comp_name: String, component: ItemDataComponent) -> void:
	components[comp_name] = component

func get_component(comp_name: String) -> ItemDataComponent:
	return components.get(comp_name, null)

func duplicate() -> ItemInstance:
	var copy = ItemInstance.new(definition, quantity)
	for key in components.keys():
		copy.add_component(key, components[key].duplicate_component())
	return copy

func serialize() -> Dictionary:
	var comps_data = {}
	for key in components.keys():
		comps_data[key] = {
			"script_path": components[key].get_script().resource_path,
			"data": components[key].serialize()
		}
		
	return {
		"item_path": definition.resource_path if definition else "",
		"quantity": quantity,
		"components": comps_data
	}

static func deserialize(data: Dictionary) -> ItemInstance:
	var item_path = data.get("item_path", "")
	var p_quantity = data.get("quantity", 1)
	if item_path.is_empty() or not ResourceLoader.exists(item_path):
		return null
		
	var def = load(item_path) as ItemDefinition
	if not def:
		return null
		
	var instance = ItemInstance.new(def, p_quantity)
	
	var comps_data = data.get("components", {})
	for key in comps_data.keys():
		var comp_dict = comps_data[key]
		var script_path = comp_dict.get("script_path", "")
		if ResourceLoader.exists(script_path):
			var script = load(script_path)
			if script and script.can_instantiate():
				var comp = script.new() as ItemDataComponent
				if comp:
					comp.deserialize(comp_dict.get("data", {}))
					instance.add_component(key, comp)
					
	return instance
