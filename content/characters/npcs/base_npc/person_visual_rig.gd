## Encapsulates person visual rig behavior: collision scaling, head/weapon anchors, and billboard-facing alignment.
class_name PersonVisualRig
extends Node


## Called by PersonActor whenever its PersonDefinition changes.
func apply_person_definition(definition: PersonDefinition) -> void:
	if definition == null:
		return
	var target_height := _apply_sprite_definition(definition)
	apply_collision_shape_from_height(target_height)
	apply_head_rig_from_height(target_height)


func _apply_sprite_definition(definition: PersonDefinition) -> float:
	var target_height := maxf(definition.height_meters, 0.1)
	var owner_node := get_parent() as Node3D
	if owner_node == null:
		return target_height
	var sprite := owner_node.get_node_or_null("Sprite3D") as Sprite3D
	if sprite == null:
		return target_height
	sprite.texture = definition.body_texture
	sprite.scale = definition.sprite_scale
	sprite.modulate = definition.sprite_tint
	var texture_height := sprite.texture.get_height() if sprite.texture else 0
	var scaled_height_factor: float = definition.sprite_scale.y if not is_zero_approx(definition.sprite_scale.y) else 1.0
	var world_height := 0.0
	if texture_height > 0 and definition.height_meters > 0.0:
		sprite.pixel_size = definition.height_meters / (float(texture_height) * scaled_height_factor)
		world_height = definition.height_meters
	elif texture_height > 0 and sprite.pixel_size > 0.0:
		world_height = sprite.pixel_size * float(texture_height) * scaled_height_factor
	if world_height > 0.0:
		var sprite_position := sprite.position
		sprite_position.y = world_height * 0.5
		sprite.position = sprite_position
		target_height = world_height
	return target_height


func apply_collision_shape_from_height(target_height: float) -> void:
	if target_height <= 0.0:
		return
	var owner_node := get_parent() as Node3D
	if owner_node == null:
		return
	var collision := owner_node.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null:
		return
	if collision.shape is CapsuleShape3D:
		var capsule := collision.shape as CapsuleShape3D
		var target_radius := clampf(target_height * 0.16, 0.18, 0.45)
		capsule.radius = target_radius
		capsule.height = maxf(target_height - (target_radius * 2.0), target_radius * 0.5)
	var collision_position := collision.position
	collision_position.y = target_height * 0.5
	collision.position = collision_position


func apply_head_rig_from_height(target_height: float) -> void:
	if target_height <= 0.0:
		return
	var owner_node := get_parent() as Node3D
	if owner_node == null:
		return
	var head_anchor_node := owner_node.get_node_or_null("HeadAnchor") as Node3D
	if head_anchor_node != null:
		var anchor_position := head_anchor_node.position
		anchor_position.y = target_height * 0.85
		head_anchor_node.position = anchor_position


func update_billboard_attachment_facing() -> void:
	var owner_node := get_parent() as Node3D
	if owner_node == null:
		return
	var camera := owner_node.get_viewport().get_camera_3d()
	if camera == null:
		return
	var head_anchor_node := owner_node.get_node_or_null("HeadAnchor") as Node3D
	var weapon_hold_node := owner_node.get_node_or_null("WeaponHold") as Node3D
	var rig_node := head_anchor_node if head_anchor_node != null else weapon_hold_node
	if rig_node == null:
		return
	var to_camera := camera.global_position - rig_node.global_position
	to_camera.y = 0.0
	if to_camera.length_squared() <= 0.0001:
		return
	var desired_global_yaw := atan2(-to_camera.x, -to_camera.z)
	var parent_3d := rig_node.get_parent() as Node3D
	if parent_3d != null:
		rig_node.rotation.y = desired_global_yaw - parent_3d.global_rotation.y
	else:
		rig_node.rotation.y = desired_global_yaw


func reset_attachment_reference_cache() -> void:
	pass
