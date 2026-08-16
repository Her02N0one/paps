extends SceneTree

const MAIN_MENU_SCENE := preload("res://scenes/main/main_menu.tscn")


class TestSaveManager extends SaveManager:
	var has_save_value := false
	var load_success := false
	var load_requests := 0

	func has_save() -> bool:
		return has_save_value

	func load_game(filename: String = "") -> bool:
		load_requests += 1
		return load_success


class TestGameManager extends GameManager:
	var start_new_game_requests: Array[String] = []
	var continue_requests := 0
	var fade_in_requests := 0

	func start_new_game(initial_map: String, _new_game_spawn_marker_id: StringName = &"") -> void:
		start_new_game_requests.append(initial_map)

	func continue_game() -> void:
		continue_requests += 1

	func fade_in() -> void:
		fade_in_requests += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_manager := TestGameManager.new()
	var save_manager := TestSaveManager.new()
	save_manager.has_save_value = false
	save_manager.load_success = false

	var main_menu := MAIN_MENU_SCENE.instantiate() as MainMenuContext
	main_menu.bind_services(game_manager, save_manager)
	root.add_child(main_menu)
	await process_frame
	await process_frame

	var warnings := main_menu.call("_get_configuration_warnings") as PackedStringArray
	var warnings_ok := warnings.is_empty()
	var fade_ok := game_manager.fade_in_requests == 1

	main_menu.new_game_start_scene = "res://missing_scene.tscn"
	var invalid_warnings := main_menu.call("_get_configuration_warnings") as PackedStringArray
	var invalid_scene_warning := false
	for warning in invalid_warnings:
		if String(warning).contains("new_game_start_scene"):
			invalid_scene_warning = true
			break
	main_menu.call("_on_new_game_pressed")
	var blocked_invalid_start := game_manager.start_new_game_requests.is_empty()

	main_menu.new_game_start_scene = "res://scenes/maps/playground.tscn"
	main_menu.call("_on_new_game_pressed")
	var valid_start_ok := game_manager.start_new_game_requests == ["res://scenes/maps/playground.tscn"]

	main_menu.call("_on_continue_pressed")
	var blocked_continue_ok := game_manager.continue_requests == 0 and save_manager.load_requests == 1

	save_manager.load_success = true
	main_menu.call("_on_continue_pressed")
	var continue_ok := game_manager.continue_requests == 1 and save_manager.load_requests == 2

	main_menu.queue_free()
	await process_frame

	if not warnings_ok or not fade_ok or not invalid_scene_warning or not blocked_invalid_start or not valid_start_ok or not blocked_continue_ok or not continue_ok:
		push_error("MainMenuContext contract regression detected.")
		quit(1)
		return
	quit()
