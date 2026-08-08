extends Node3D

@onready var game_ui: Control = $CanvasLayer/GameUI
@onready var intro_panel: Control = $CanvasLayer/GameUI/IntroPanel
@onready var pause_panel: Control = $CanvasLayer/GameUI/PausePanel
@onready var map_container: Node3D = $MapContainer
@onready var player: CharacterBody3D = $CharacterBody3D

var can_pause := false


func _ready() -> void:
	add_to_group("world")
	process_mode = Node.PROCESS_MODE_ALWAYS
	game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	intro_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	intro_panel.visible = true
	pause_panel.visible = false
	can_pause = false
	GameManager.on_world_ready(self)


func _unhandled_input(event: InputEvent) -> void:
	if not can_pause:
		return

	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			_resume_game()
		else:
			_open_pause_menu()


# Frees the current map and instances the new one, then positions the player.
func swap_map(scene_path: String, spawn_id: String, reversed: bool = false) -> void:
	for child in map_container.get_children():
		child.queue_free()
	var map: Node = load(scene_path).instantiate()
	map_container.add_child(map)
	_apply_spawn.call_deferred(spawn_id, reversed)


func _apply_spawn(target_id: String, reversed: bool = false) -> void:
	var target: Node = null
	var is_gateway := false
	if target_id != "":
		for gw in get_tree().get_nodes_in_group("gateways"):
			if gw.gateway_id == target_id:
				target = gw
				is_gateway = true
				break
	if target == null:
		for s in get_tree().get_nodes_in_group("spawn_points"):
			if s.spawn_id == "":
				target = s
				break
	if target == null:
		return
	if is_gateway:
		var walk_start: Node3D = target.get_node_or_null("WalkStart")
		var walk_end: Node3D = target.get_node_or_null("WalkEnd")
		if walk_start and walk_end:
			var walk_dir := (walk_end.global_position - walk_start.global_position).normalized()
			var dist: float = walk_start.global_position.distance_to(walk_end.global_position)
			player.global_position = walk_start.global_position
			# reversed: face back toward the gateway, still walk in same direction (backing away)
			player.rotation.y = atan2(walk_dir.x, walk_dir.z) if reversed else atan2(-walk_dir.x, -walk_dir.z)
			player.get_node("Head").rotation.y = 0.0
			player.start_arrival_walk(walk_dir, dist)
		else:
			player.global_position = target.global_position
			player.get_node("Head").rotation.y = 0.0
	else:
		player.global_position = target.global_position
		player.rotation.y = target.rotation.y
		player.get_node("Head").rotation.y = 0.0


func _on_intro_continue_pressed() -> void:
	intro_panel.visible = false
	can_pause = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	_resume_game()


func _on_quit_to_menu_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.quit_to_menu()


func _on_quit_game_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()


func _open_pause_menu() -> void:
	pause_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume_game() -> void:
	pause_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
