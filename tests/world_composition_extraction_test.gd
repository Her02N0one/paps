extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")
const TARGET_AREA := "res://scenes/docs/gym.tscn"
const SCRAP := preload("res://resources/items/scrap.tres")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := GameState.new()
	root.add_child(game_state)
	await process_frame

	var save_manager := SaveManager.new()
	root.add_child(save_manager)

	var game_manager := GameManager.new()
	root.add_child(game_manager)
	game_manager.configure(save_manager, game_state)
	game_manager.set_context_switch_callbacks(func(_a: String, _b: String, _c: bool) -> void: pass, func() -> void: pass)

	game_state.reset(TARGET_AREA)
	game_state.enter_area(TARGET_AREA)
	var dynamic_id := game_state.add_dynamic_pickup(TARGET_AREA, SCRAP, 2, Transform3D(Basis.IDENTITY, Vector3(4.0, 1.0, 1.5)))
	var person_id := StringName("jerry")
	game_state.register_person_if_missing(person_id, TARGET_AREA, "res://scenes/person.tscn", Transform3D(Basis.IDENTITY, Vector3(1.5, 0.0, 2.5)), {})

	var world := WORLD_SCENE.instantiate() as World
	world.bind_services(game_manager, game_state, save_manager)
	root.add_child(world)
	await process_frame
	var runtime_player_present := world.player != null

	var swapped := world.swap_map(TARGET_AREA, "", false)
	if not swapped:
		push_error("World composition regression: swap_map failed for test area.")
		quit(1)
		return

	# World restore work is deferred; allow those operations to run.
	await process_frame
	await process_frame
	await process_frame

	var restored_dynamic := false
	var restored_person := false
	for child in world.entity_root.get_children():
		if child is PickupItem and (child as PickupItem).dynamic_id == dynamic_id:
			restored_dynamic = true
		if child is PersonActor and (child as PersonActor).get_person_id() == person_id:
			restored_person = true

	if not runtime_player_present or not restored_dynamic or not restored_person:
		push_error("World composition regression: extracted lifecycle components did not restore expected entities.")
		quit(1)
		return

	quit()
