extends SceneTree

const RUN_CONTEXT_SCENE := preload("res://scenes/run/run_context.tscn")
const CONTEXT_NONE := &""
const CONTEXT_MAP := &"map"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var run_context: Node = RUN_CONTEXT_SCENE.instantiate()
	root.add_child(run_context)
	await process_frame

	run_context.connect("map_swap_requested", func(scene_path: String, _spawn_id: String, _reversed: bool) -> void:
		run_context.call("report_map_swap_result", true, scene_path)
	)
	var requested_swap_ok: bool = bool(run_context.call("request_map_swap", "res://scenes/docs/gym.tscn", "", false))
	var area_path_ok: bool = str(run_context.call("get_current_area_path")) == "res://scenes/docs/gym.tscn"

	var opened_map: bool = bool(run_context.call("open_context", CONTEXT_MAP))
	var active_after_map: StringName = run_context.call("get_active_context_id") as StringName
	var map_ok: bool = opened_map and active_after_map == CONTEXT_MAP

	var payload_ok := false
	var active_node: Node = run_context.call("get_active_context_node") as Node
	if active_node != null and active_node.has_method("get_last_payload"):
		var payload: Dictionary = active_node.call("get_last_payload") as Dictionary
		payload_ok = str(payload.get("area_path", "")) == "res://scenes/docs/gym.tscn"

	run_context.call("close_active_context")
	var active_after_close: StringName = run_context.call("get_active_context_id") as StringName
	var closed_ok: bool = active_after_close == CONTEXT_NONE

	if not requested_swap_ok or not area_path_ok or not map_ok or not payload_ok or not closed_ok:
		push_error("RunContext composition regression detected.")
		quit(1)
		return
	quit()
