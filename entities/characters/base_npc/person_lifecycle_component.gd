## Restores persisted PersonActor instances for the active area.
class_name PersonLifecycleComponent
extends RefCounted

const SCENE_SPAWN_SERVICE := preload("res://systems/zone_management/scene_spawn_service.gd")

var _game_state: GameState
var _entity_root: Node3D
var _spawn_service: SceneSpawnService


func configure(game_state: GameState, entity_root: Node3D) -> void:
	_game_state = game_state
	_entity_root = entity_root
	_spawn_service = SCENE_SPAWN_SERVICE.new()


func restore_persisted_people(area_path: String, current_level: BaseLevel) -> void:
	if _game_state == null or _entity_root == null or current_level == null:
		return
	var people := _game_state.get_people_in_area(area_path)
	if people.is_empty():
		return
	var loaded_ids: Dictionary = {}
	for child in current_level.find_children("*", "CharacterBody3D", true, false):
		if child is PersonActor:
			loaded_ids[(child as PersonActor).get_person_id()] = true
	for person_id in people:
		if loaded_ids.has(person_id):
			continue
		var record := people[person_id] as Dictionary
		var scene_path := str(record.get("scene_path", ""))
		if scene_path.is_empty() or not ResourceLoader.exists(scene_path, "PackedScene"):
			push_warning("Skipping persisted person '%s' with invalid scene path '%s'." % [person_id, scene_path])
			continue
		var person := _spawn_service.instantiate_detached_from_path(scene_path, &"PersonActor") as PersonActor
		if person == null:
			push_warning("Skipping persisted person '%s' because scene is invalid or not a PersonActor root." % person_id)
			continue
		person.person_id = person_id
		person.apply_profile(record.get("profile", {}) as Dictionary)
		var saved_transform = record.get("transform")
		if typeof(saved_transform) == TYPE_TRANSFORM3D:
			person.global_transform = saved_transform
		_entity_root.add_child(person)
