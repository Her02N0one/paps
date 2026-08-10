extends SceneTree

const ROOT_CONTEXT_SCENE := preload("res://scenes/root_context.tscn")
const CONTEXT_MAIN_MENU := &"main_menu"
const CONTEXT_WORLD := &"world"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var root_context := ROOT_CONTEXT_SCENE.instantiate() as RootContext
	root.add_child(root_context)
	await process_frame
	await process_frame

	var services_ok := (
		root_context.game_state != null
		and root_context.save_manager != null
		and root_context.game_manager != null
		and root_context.settings_manager != null
	)
	var menu_context_ok := root_context.get_active_context_id() == CONTEXT_MAIN_MENU

	root_context.show_world_context("", "", false)
	await process_frame
	await process_frame
	var world_context_node := root_context.get_active_context_node()
	var world_context_ok := (
		root_context.get_active_context_id() == CONTEXT_WORLD
		and world_context_node != null
		and world_context_node is World
		and world_context_node.get_node_or_null("Systems/WorldUIController") != null
		and world_context_node.get_node_or_null("Systems/RunContext") != null
		and world_context_node.get_node_or_null("GameplayWorld/LevelRoot") != null
		and world_context_node.get_node_or_null("GameplayWorld/EntityRoot") != null
		and world_context_node.get_node_or_null("GameplayWorld/EffectRoot") != null
	)

	root_context.show_main_menu_context()
	await process_frame
	await process_frame
	var menu_return_ok := root_context.get_active_context_id() == CONTEXT_MAIN_MENU

	root_context.queue_free()
	await process_frame

	if not services_ok or not menu_context_ok or not world_context_ok or not menu_return_ok:
		push_error("RootContext contract regression: top-level services or context wiring changed unexpectedly.")
		quit(1)
		return
	quit()
