extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var original_overlay := StandardMaterial3D.new()
	var interactable := Interactable.new()
	mesh.mesh = BoxMesh.new()
	mesh.material_overlay = original_overlay
	body.add_child(mesh)
	body.add_child(interactable)
	root.add_child(body)
	await process_frame

	interactable.highlight()
	var outline_mesh := mesh.get_node_or_null("InteractionOutline") as MeshInstance3D
	var outline: ShaderMaterial = outline_mesh.material_override as ShaderMaterial if outline_mesh else null
	var outline_is_valid: bool = (
		outline_mesh != null
		and outline_mesh.mesh == mesh.mesh
		and outline != null
		and outline.shader != null
		and outline.get_shader_parameter(&"outline_color") == interactable.outline_color
		and is_equal_approx(outline.get_shader_parameter(&"outline_width"), interactable.outline_width)
	)
	interactable.unhighlight()
	await process_frame
	var outline_was_removed := not mesh.has_node("InteractionOutline")
	var overlay_was_preserved := mesh.material_overlay == original_overlay

	if not outline_is_valid or not outline_was_removed or not overlay_was_preserved:
		push_error("Interactable outline regression detected.")
		quit(1)
		return
	quit()
