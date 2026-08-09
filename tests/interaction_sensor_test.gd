extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cast := ShapeCast3D.new()
	var cast_shape := SphereShape3D.new()
	cast_shape.radius = 0.55
	cast.shape = cast_shape
	cast.target_position = Vector3(0.0, 0.0, -4.0)
	cast.collision_mask = 2
	cast.max_results = 8

	var sensor := InteractionSensorComponent.new()
	sensor.shape_cast = cast
	var centered_item := _create_item(Vector3(0.1, 0.0, -3.5))
	var nearby_item := _create_item(Vector3(0.45, 0.0, -2.0))
	root.add_child(cast)
	root.add_child(sensor)
	root.add_child(centered_item)
	root.add_child(nearby_item)
	await physics_frame
	await physics_frame

	cast.force_shapecast_update()
	sensor.physics_tick()
	if sensor.get_current_interactable() != Interactable.find_on(centered_item):
		push_error("Interaction conflict did not select the center closest to the view ray.")
		quit(1)
		return
	quit()


func _create_item(position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	var collision := CollisionShape3D.new()
	var collision_shape := SphereShape3D.new()
	collision_shape.radius = 0.15
	collision.shape = collision_shape
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh.mesh = sphere
	body.add_child(collision)
	body.add_child(mesh)
	body.add_child(Interactable.new())
	return body
