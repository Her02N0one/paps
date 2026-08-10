extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var controller := ModalStateController.new()
	var first_panel := Control.new()
	var second_panel := Control.new()
	var crosshair := Control.new()
	root.add_child(controller)
	root.add_child(first_panel)
	root.add_child(second_panel)
	root.add_child(crosshair)
	controller.configure({&"first": first_panel}, crosshair)
	controller.register_panel(&"second", second_panel)

	controller.open(&"first")
	var first_opened := first_panel.visible and not second_panel.visible and not crosshair.visible and paused
	controller.open(&"second")
	var second_opened := not first_panel.visible and second_panel.visible and controller.active_modal == &"second"
	var closed := controller.close(&"second") and not paused and crosshair.visible

	if not first_opened or not second_opened or not closed:
		push_error("Modal state registry regression detected.")
		quit(1)
		return
	quit()