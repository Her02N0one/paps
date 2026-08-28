extends SceneTree

const PERSON_COMPONENT_SCRIPT := preload("res://content/characters/npcs/base_npc/person_lifecycle_system.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := GameState.new()
	root.add_child(game_state)
	await process_frame

	var entity_root := Node3D.new()
	root.add_child(entity_root)

	var level := BaseLevel.new()
	root.add_child(level)

	var area_path := "res://devtools/sandbox/gym.tscn"
	var person_id := StringName("jerry")
	game_state.enter_area(area_path)
	game_state.register_person_if_missing(person_id, area_path, "res://content/characters/npcs/jerry/person_jerry.tscn", Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 2.0)), {})

	var component = PERSON_COMPONENT_SCRIPT.new()
	component.configure(game_state, entity_root)
	component.restore_persisted_people(area_path, level)
	await process_frame

	var restored_count := entity_root.get_child_count()
	var restored_person := entity_root.get_child(0) as PersonActor if restored_count > 0 else null
	var restored_id_ok := restored_person != null and restored_person.get_person_id() == person_id

	if not restored_id_ok:
		push_error("Person lifecycle component regression detected.")
		quit(1)
		return
	quit()
