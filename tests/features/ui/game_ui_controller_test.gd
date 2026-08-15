extends SceneTree

const PLAYER_SCENE := preload("res://entities/characters/player/player.tscn")
const INTRO_PANEL_SCENE := preload("res://systems/ui/intro_panel.tscn")

var _custom_dispatch_count := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var host := Node.new()
	host.name = "Host"
	root.add_child(host)

	var player := PLAYER_SCENE.instantiate() as Player
	host.add_child(player)
	var intro_panel := INTRO_PANEL_SCENE.instantiate() as IntroPanelSurface
	intro_panel.name = "IntroPanel"
	host.add_child(intro_panel)

	var modal_state := ModalStateController.new()
	modal_state.name = "ModalStateController"
	host.add_child(modal_state)

	var controller := GameUIController.new()
	controller.name = "WorldUIController"
	controller.player_path = NodePath("../Player")
	controller.intro_panel_path = NodePath("../IntroPanel")
	controller.auto_resolve_scene_nodes = false
	host.add_child(controller)

	# Ensure _ready has executed for both nodes.
	await process_frame

	var request := PlayerInteractionRequest.new(&"custom_action", null, null, {"value": 7})
	controller.register_player_interaction(&"custom_action", _on_custom_interaction)
	controller._on_player_interaction_requested(request)
	var dispatch_routed := _custom_dispatch_count == 1

	var panel := GamePanel.new()
	panel.modal_id = &"test_modal"
	host.add_child(panel)
	await process_frame
	modal_state.open(&"test_modal")
	var opened := modal_state.active_modal == &"test_modal" and panel.visible

	panel.close_panel()
	var closed := modal_state.active_modal == ModalStateController.NONE and not panel.visible

	controller.start_world_session(false)
	var session_started := controller.can_pause and modal_state.active_modal == ModalStateController.NONE
	controller.start_world_session(true)
	var intro_opened := not controller.can_pause and modal_state.active_modal == controller.MODAL_INTRO
	intro_panel.continue_pressed.emit()
	var intro_closed := controller.can_pause and modal_state.active_modal == ModalStateController.NONE

	host.queue_free()
	await process_frame

	if not dispatch_routed or not opened or not closed or not session_started or not intro_opened or not intro_closed:
		push_error("Game UI controller routing/modal integration regression detected.")
		quit(1)
		return
	quit()


func _on_custom_interaction(_request: PlayerInteractionRequest) -> void:
	_custom_dispatch_count += 1
