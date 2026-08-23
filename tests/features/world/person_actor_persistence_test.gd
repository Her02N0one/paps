extends SceneTree

const PERSON_SCENE := preload("res://entities/characters/base_npc/simple_npc.tscn")
const PLAYGROUND_SCENE := "res://levels/maps/playground.tscn"
const OTHER_SCENE := "res://levels/maps/zone_b.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := GameState.new()
	root.add_child(game_state)
	await process_frame

	game_state.enter_area(PLAYGROUND_SCENE)
	var saved_transform := Transform3D(Basis.IDENTITY, Vector3(3.0, 4.0, 5.0))
	game_state.update_person_record(&"unit_person", PLAYGROUND_SCENE, saved_transform, "res://entities/characters/jerry/person_jerry.tscn")

	var primary := PERSON_SCENE.instantiate() as PersonActor
	primary.person_id = &"unit_person"
	var image := Image.create(16, 64, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	var profile := PersonDefinition.new()
	profile.speaker_name = "Unit"
	profile.body_texture = texture
	profile.height_meters = 2.0
	profile.sprite_scale = Vector3.ONE
	primary.definition = profile
	primary.name = "UnitPerson"
	root.add_child(primary)
	await process_frame

	var restored_transform_ok := is_instance_valid(primary) and primary.global_position.is_equal_approx(saved_transform.origin)
	var sprite := primary.get_node_or_null("Sprite3D") as Sprite3D
	var visual_height_ok := (
		sprite != null
		and sprite.texture != null
		and is_equal_approx(sprite.pixel_size * float(sprite.texture.get_height()) * sprite.scale.y, 2.0)
	)
	var feet_anchored_ok := (
		sprite != null
		and sprite.texture != null
		and is_equal_approx(sprite.position.y - ((sprite.pixel_size * float(sprite.texture.get_height()) * sprite.scale.y) * 0.5), 0.0)
	)

	profile.height_meters = 3.0
	await process_frame
	var live_height_update_ok := (
		sprite != null
		and sprite.texture != null
		and is_equal_approx(sprite.pixel_size * float(sprite.texture.get_height()) * sprite.scale.y, 3.0)
		and is_equal_approx(sprite.position.y - ((sprite.pixel_size * float(sprite.texture.get_height()) * sprite.scale.y) * 0.5), 0.0)
	)

	primary.set_person_height_meters(1.5)
	await process_frame
	var height_api_ok := (
		sprite != null
		and sprite.texture != null
		and is_equal_approx(sprite.pixel_size * float(sprite.texture.get_height()) * sprite.scale.y, 1.5)
	)

	var clone := PERSON_SCENE.instantiate() as PersonActor
	clone.person_id = &"unit_person"
	clone.name = "UnitPersonClone"
	root.add_child(clone)
	await process_frame

	var clone_rejected := not is_instance_valid(clone) or clone.is_queued_for_deletion()

	game_state.update_person_record(&"other_area_person", OTHER_SCENE, Transform3D(Basis.IDENTITY, Vector3.ZERO), "res://entities/characters/jerry/person_jerry.tscn")
	var wrong_area_person := PERSON_SCENE.instantiate() as PersonActor
	wrong_area_person.person_id = &"other_area_person"
	wrong_area_person.name = "WrongAreaPerson"
	root.add_child(wrong_area_person)
	await process_frame

	var wrong_area_rejected := not is_instance_valid(wrong_area_person) or wrong_area_person.is_queued_for_deletion()

	primary.set_person_state_value(&"mood", "curious")
	primary.set_person_flag(&"met_player", true)
	var state_roundtrip_ok := (
		str(game_state.get_person_state_value(&"unit_person", &"mood", "")) == "curious"
		and game_state.get_person_flag(&"unit_person", &"met_player", false)
	)

	primary.set_person_area(OTHER_SCENE, Transform3D(Basis.IDENTITY, Vector3(9.0, 9.0, 9.0)))
	await process_frame
	var moved_record := game_state.get_person_record(&"unit_person")
	var moved_area_ok := (
		str(moved_record.get("area_path", "")) == OTHER_SCENE
		and game_state.is_person_enabled(&"unit_person")
	)

	var teleported := PERSON_SCENE.instantiate() as PersonActor
	teleported.person_id = &"teleport_person"
	teleported.definition = profile
	root.add_child(teleported)
	await process_frame
	teleported.teleport_person_to(Vector3(7.0, 8.0, 9.0))
	var teleported_record := game_state.get_person_record(&"teleport_person")
	var teleport_api_ok := (
		typeof(teleported_record.get("transform")) == TYPE_TRANSFORM3D
		and (teleported_record.get("transform") as Transform3D).origin.is_equal_approx(Vector3(7.0, 8.0, 9.0))
	)

	game_state.update_person_record(&"disabled_person", PLAYGROUND_SCENE, Transform3D(Basis.IDENTITY, Vector3.ZERO), "res://entities/characters/jerry/person_jerry.tscn")
	game_state.set_person_enabled(&"disabled_person", false)
	var disabled_person := PERSON_SCENE.instantiate() as PersonActor
	disabled_person.person_id = &"disabled_person"
	disabled_person.name = "DisabledPerson"
	root.add_child(disabled_person)
	await process_frame
	var disabled_rejected := not is_instance_valid(disabled_person) or disabled_person.is_queued_for_deletion()

	if not restored_transform_ok or not visual_height_ok or not feet_anchored_ok or not live_height_update_ok or not height_api_ok or not clone_rejected or not wrong_area_rejected or not state_roundtrip_ok or not moved_area_ok or not teleport_api_ok or not disabled_rejected:
		push_error("PersonActor persistence/clone protection regression detected.")
		quit(1)
		return
	quit()
