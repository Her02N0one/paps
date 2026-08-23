class_name HitscanBehavior
extends WeaponBehavior

@export var muzzle_flash: GPUParticles3D
@export var range := 100.0
@export var base_damage := 10.0

func execute_attack(stats: Resource, camera: Camera3D) -> void:
	if muzzle_flash:
		muzzle_flash.restart()
		
	var space = camera.get_world_3d().direct_space_state
	var origin = camera.global_position
	var forward = -camera.global_transform.basis.z
	
	var query = PhysicsRayQueryParameters3D.create(origin, origin + forward * range)
	var result = space.intersect_ray(query)
	
	if result:
		var collider = result.collider
		if collider.has_method("apply_damage"):
			collider.apply_damage(base_damage)
			
	# Trigger visual recoil on the view-model (self)
	var recoil_tween = create_tween()
	position.z += 0.1
	rotation.x += 0.1
	recoil_tween.tween_property(self, "position:z", 0.0, 0.1)
	recoil_tween.parallel().tween_property(self, "rotation:x", 0.0, 0.1)
