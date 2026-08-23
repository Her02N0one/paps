class_name WeaponBehavior
extends Node3D

## Base class attached to the root of a view-model scene.
## Decouples firing logic from the player controller.

func execute_attack(stats: Resource, camera: Camera3D) -> void:
	pass

func release_attack() -> void:
	pass
