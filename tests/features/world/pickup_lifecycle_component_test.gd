extends SceneTree

const PICKUP_COMPONENT_SCRIPT := preload("res://scripts/features/world/pickup_lifecycle_component.gd")
const PICKUP_SCENE := preload("res://scenes/world/entities/pickup_item.tscn")
const SCRAP := preload("res://resources/items/scrap.tres")


class TestSaveManager:
	extends SaveManager

	var save_calls := 0

	func save_game(_slot: int = 0) -> bool:
		save_calls += 1
		return true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := GameState.new()
	root.add_child(game_state)
	await process_frame

	var save_manager := TestSaveManager.new()
	root.add_child(save_manager)

	var entity_root := Node3D.new()
	root.add_child(entity_root)

	var component = PICKUP_COMPONENT_SCRIPT.new()
	component.configure(game_state, save_manager, entity_root, PICKUP_SCENE)

	var area_path := "res://scenes/docs/gym.tscn"
	game_state.enter_area(area_path)
	var dynamic_id := game_state.add_dynamic_pickup(area_path, SCRAP, 2, Transform3D(Basis.IDENTITY, Vector3(2.0, 1.0, 3.0)), {
		"properties": [
			{
				"node_path": "Interactable",
				"property": "interact_label",
				"value": "Special pickup",
			}
		],
	})

	component.restore_dynamic_pickups(area_path)
	var spawned := entity_root.get_child_count() == 1
	var restored_pickup := entity_root.get_child(0) as PickupItem
	var nested_override_applied := false
	if restored_pickup:
		var interactable := restored_pickup.get_node_or_null("Interactable") as Interactable
		nested_override_applied = interactable != null and interactable.interact_label == "Special pickup"

	component.handle_pickup_collected("", dynamic_id)
	var removed_from_state := not game_state.get_dynamic_pickups(area_path).has(dynamic_id)
	var save_called := save_manager.save_calls >= 1

	if not spawned or not nested_override_applied or not removed_from_state or not save_called:
		push_error("Pickup lifecycle component regression detected.")
		quit(1)
		return
	quit()
