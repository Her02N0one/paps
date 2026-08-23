class_name EquipmentHolderComponent
extends Node3D

@export var camera: Camera3D

var active_behavior: WeaponBehavior = null

func equip_view_model(view_model_scene: PackedScene) -> void:
	# Clear existing
	for child in get_children():
		child.queue_free()
		
	if view_model_scene:
		var instance = view_model_scene.instantiate()
		add_child(instance)
		if instance is WeaponBehavior:
			active_behavior = instance as WeaponBehavior
		else:
			# Search for the behavior
			for child in instance.get_children():
				if child is WeaponBehavior:
					active_behavior = child
					break

func fire() -> void:
	if active_behavior and camera:
		# Use a dummy stats resource for now
		active_behavior.execute_attack(null, camera)

func release_fire() -> void:
	if active_behavior:
		active_behavior.release_attack()
