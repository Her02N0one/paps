extends SceneTree

const GAME_MANAGER_SCRIPT := preload("res://scripts/context/game_manager.gd")


class TestSaveManager extends SaveManager:
	var new_game_requests: Array[String] = []
	var save_requests := 0

	func start_new_game(initial_area: String, _slot: int = DEFAULT_SLOT) -> bool:
		new_game_requests.append(initial_area)
		return true

	func save_game(_slot: int = DEFAULT_SLOT) -> bool:
		save_requests += 1
		return true


class TestGameState extends GameState:
	pass


func _initialize() -> void:
	var save_manager := TestSaveManager.new()
	var game_state := TestGameState.new()
	game_state.current_area = "res://scenes/zone_b.tscn"

	var new_game_manager := GAME_MANAGER_SCRIPT.new()
	new_game_manager.configure(save_manager, game_state)
	new_game_manager.set_context_switch_callbacks(func(_map: String, _spawn: String, _reversed: bool) -> void: pass, func() -> void: pass)
	new_game_manager.start_new_game("res://scenes/playground.tscn")
	var new_game_requested: bool = (
		save_manager.new_game_requests == ["res://scenes/playground.tscn"]
		and new_game_manager.pending_target_map == "res://scenes/playground.tscn"
		and new_game_manager.consume_intro_request()
	)

	var continue_manager := GAME_MANAGER_SCRIPT.new()
	continue_manager.configure(save_manager, game_state)
	continue_manager.set_context_switch_callbacks(func(_map: String, _spawn: String, _reversed: bool) -> void: pass, func() -> void: pass)
	continue_manager.continue_game()
	var continue_requested: bool = continue_manager.pending_target_map == game_state.current_area

	var travel_manager := GAME_MANAGER_SCRIPT.new()
	travel_manager.configure(save_manager, game_state)
	travel_manager.set_context_switch_callbacks(func(_map: String, _spawn: String, _reversed: bool) -> void: pass, func() -> void: pass)
	travel_manager.travel("res://scenes/playground.tscn", "gate_a", true)
	var travel_requested: bool = (
		save_manager.save_requests == 1
		and travel_manager.pending_target_map == "res://scenes/playground.tscn"
		and travel_manager.pending_target_spawn_id == "gate_a"
		and travel_manager.pending_entry_reversed
	)

	var unconfigured_save_manager := TestSaveManager.new()
	var unconfigured_callbacks_manager := GAME_MANAGER_SCRIPT.new()
	unconfigured_callbacks_manager.configure(unconfigured_save_manager, game_state)
	unconfigured_callbacks_manager.start_new_game("res://scenes/playground.tscn")
	unconfigured_callbacks_manager.continue_game()
	unconfigured_callbacks_manager.quit_to_menu()
	var callback_guard_ok: bool = (
		unconfigured_save_manager.new_game_requests.is_empty()
		and unconfigured_save_manager.save_requests == 0
		and unconfigured_callbacks_manager.pending_target_map.is_empty()
	)

	if not new_game_requested or not continue_requested or not travel_requested or not callback_guard_ok:
		push_error("Game manager dependency or transition request regression detected.")
		quit(1)
		return
	quit()