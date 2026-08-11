## Runtime weapon loop for player: fire, reload, recoil, and hitscan damage.
class_name PlayerWeaponComponent
extends Node

const WEAPON_VIEW_SCRIPT := preload("res://scripts/features/combat/weapon_view.gd")

signal weapon_fired(hit: bool, hit_position: Vector3, ammo_in_mag: int, ammo_reserve: int)
signal dry_fired(ammo_in_mag: int, ammo_reserve: int)
signal reload_started(ammo_in_mag: int, ammo_reserve: int)
signal reload_finished(ammo_in_mag: int, ammo_reserve: int)

@export var body: CharacterBody3D
@export var camera: Camera3D
@export var sway_pivot: Node3D
@export var weapon_definition: Resource
@export var auto_reload_on_empty := true
@export var viewmodel_return_speed := 11.0
@export var camera_shake_decay := 24.0
@export var camera_shake_amount := 0.015

var _ammo_in_mag := 0
var _ammo_reserve := 0
var _shot_cooldown_remaining := 0.0
var _reload_remaining := 0.0
var _fov_kick := 0.0
var _kickback_offset := 0.0
var _kickback_side_offset := 0.0
var _kickback_vertical_offset := 0.0
var _camera_shake_strength := 0.0
var _weapon_view_instance: Node3D
var _weapon_view_adapter: Node


func _ready() -> void:
	if body == null and get_parent() is CharacterBody3D:
		body = get_parent() as CharacterBody3D
	if sway_pivot == null and camera != null:
		sway_pivot = camera.get_node_or_null("WeaponSwayPivot") as Node3D
	_initialize_ammo()
	_equip_weapon_view()


func _initialize_ammo() -> void:
	var definition := _get_weapon_definition()
	if definition == null:
		_ammo_in_mag = 0
		_ammo_reserve = 0
		return
	_ammo_in_mag = definition.magazine_size
	_ammo_reserve = definition.reserve_ammo


func _physics_process(delta: float) -> void:
	_shot_cooldown_remaining = maxf(_shot_cooldown_remaining - delta, 0.0)
	if _reload_remaining > 0.0:
		_reload_remaining = maxf(_reload_remaining - delta, 0.0)
		if is_zero_approx(_reload_remaining):
			_finish_reload()


func _process(delta: float) -> void:
	# Decay kicks quickly so shots feel punchy without long camera drift.
	_fov_kick = move_toward(_fov_kick, 0.0, delta * 7.5)
	var return_speed := maxf(viewmodel_return_speed, 0.1)
	_kickback_offset = move_toward(_kickback_offset, 0.0, delta * return_speed)
	_kickback_side_offset = move_toward(_kickback_side_offset, 0.0, delta * return_speed * 1.1)
	_kickback_vertical_offset = move_toward(_kickback_vertical_offset, 0.0, delta * return_speed)
	_camera_shake_strength = move_toward(_camera_shake_strength, 0.0, delta * maxf(camera_shake_decay, 0.1))
	if sway_pivot:
		var local_pos := sway_pivot.position
		local_pos.x = _kickback_side_offset
		local_pos.y = _kickback_vertical_offset
		local_pos.z = -_kickback_offset
		sway_pivot.position = local_pos
	if camera:
		if _camera_shake_strength > 0.0:
			var shake_scale := _camera_shake_strength * maxf(camera_shake_amount, 0.0)
			camera.h_offset = randf_range(-shake_scale, shake_scale)
			camera.v_offset = randf_range(-shake_scale, shake_scale)
		else:
			camera.h_offset = 0.0
			camera.v_offset = 0.0


func request_fire() -> bool:
	var definition := _get_weapon_definition()
	if definition == null:
		return false
	if _reload_remaining > 0.0 or _shot_cooldown_remaining > 0.0:
		return false
	if _ammo_in_mag <= 0:
		dry_fired.emit(_ammo_in_mag, _ammo_reserve)
		_play_weapon_dry_fire_animation()
		if auto_reload_on_empty:
			request_reload()
		return false
	_ammo_in_mag -= 1
	_shot_cooldown_remaining = 1.0 / maxf(definition.shots_per_second, 0.1)
	var hit := _fire_hitscan_burst(definition)
	_apply_recoil_juice(definition)
	_play_weapon_fire_animation()
	weapon_fired.emit(hit.hit_any, hit.hit_position, _ammo_in_mag, _ammo_reserve)
	if _ammo_in_mag <= 0 and auto_reload_on_empty:
		request_reload()
	return true


func request_reload() -> bool:
	var definition := _get_weapon_definition()
	if definition == null:
		return false
	if _reload_remaining > 0.0:
		return false
	if _ammo_in_mag >= definition.magazine_size:
		return false
	if _ammo_reserve <= 0:
		return false
	_reload_remaining = definition.reload_seconds
	_play_weapon_reload_animation()
	reload_started.emit(_ammo_in_mag, _ammo_reserve)
	return true


func get_fov_kick_degrees() -> float:
	return _fov_kick


func get_ammo_in_mag() -> int:
	return _ammo_in_mag


func get_ammo_reserve() -> int:
	return _ammo_reserve


func is_reloading() -> bool:
	return _reload_remaining > 0.0


func _finish_reload() -> void:
	var definition := _get_weapon_definition()
	if definition == null:
		return
	var needed: int = maxi(definition.magazine_size - _ammo_in_mag, 0)
	var moved: int = mini(needed, _ammo_reserve)
	_ammo_in_mag += moved
	_ammo_reserve -= moved
	_play_weapon_idle_animation()
	reload_finished.emit(_ammo_in_mag, _ammo_reserve)


func _fire_hitscan_burst(definition: WeaponDefinition) -> Dictionary:
	if camera == null:
		return {"hit_any": false, "hit_position": Vector3.ZERO}
	var space := camera.get_world_3d().direct_space_state
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var max_distance := definition.range_meters
	var did_damage_any := false
	var hit_position: Vector3 = origin + forward * max_distance
	for _pellet in range(maxi(definition.pellets_per_shot, 1)):
		var shot_dir := _apply_spread(forward, definition.spread_degrees)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + shot_dir * max_distance)
		query.exclude = [body]
		var result := space.intersect_ray(query)
		if result.is_empty():
			continue
		hit_position = result.position
		if _apply_damage_if_supported(result.collider, definition.damage_per_shot):
			did_damage_any = true
	return {"hit_any": did_damage_any, "hit_position": hit_position}


func _apply_spread(base_direction: Vector3, spread_degrees: float) -> Vector3:
	if spread_degrees <= 0.0:
		return base_direction.normalized()
	var axis_right := camera.global_transform.basis.x.normalized()
	var axis_up := camera.global_transform.basis.y.normalized()
	var spread_radians := deg_to_rad(spread_degrees)
	var yaw := randf_range(-spread_radians, spread_radians)
	var pitch := randf_range(-spread_radians, spread_radians)
	var direction := base_direction.rotated(axis_up, yaw).rotated(axis_right, pitch)
	return direction.normalized()


func _apply_damage_if_supported(collider: Variant, damage_amount: float) -> bool:
	if collider == null:
		return false
	if collider.has_method("apply_damage"):
		var direct_result = collider.call("apply_damage", damage_amount, body)
		if direct_result is float or direct_result is int:
			return float(direct_result) > 0.0
		return true
	if collider is Node:
		var node := collider as Node
		if node.get_parent() and node.get_parent().has_method("apply_damage"):
			var parent_result = node.get_parent().call("apply_damage", damage_amount, body)
			if parent_result is float or parent_result is int:
				return float(parent_result) > 0.0
			return true
	return false


func _apply_recoil_juice(definition: WeaponDefinition) -> void:
	var recoil_push := definition.recoil_push_meters
	var recoil_pitch := definition.recoil_pitch_degrees
	_fov_kick = minf(_fov_kick + definition.fov_kick_degrees, 4.0)
	_kickback_offset = minf(_kickback_offset + recoil_push, 0.11)
	_kickback_side_offset = clampf(_kickback_side_offset + randf_range(-recoil_push * 0.5, recoil_push * 0.5), -0.04, 0.04)
	_kickback_vertical_offset = clampf(_kickback_vertical_offset + randf_range(-recoil_push * 0.32, -recoil_push * 0.12), -0.03, 0.015)
	_camera_shake_strength = minf(_camera_shake_strength + 1.0, 1.0)
	if camera:
		camera.rotate_x(deg_to_rad(-recoil_pitch))
		camera.rotate_y(deg_to_rad(randf_range(-recoil_pitch * 0.28, recoil_pitch * 0.28)))


func equip_weapon(next_definition: Resource, refill_ammo := true) -> void:
	weapon_definition = next_definition
	if refill_ammo:
		_initialize_ammo()
	_equip_weapon_view()


func _get_weapon_definition() -> WeaponDefinition:
	return weapon_definition as WeaponDefinition


func _equip_weapon_view() -> void:
	if _weapon_view_instance != null:
		_weapon_view_instance.queue_free()
		_weapon_view_instance = null
		_weapon_view_adapter = null
	if sway_pivot == null:
		return
	var definition := _get_weapon_definition()
	if definition == null or definition.view_scene == null:
		return
	var instantiated := definition.view_scene.instantiate()
	if not instantiated is Node3D:
		push_warning("Weapon view scene for '%s' must have a Node3D root." % definition.display_name)
		return
	_weapon_view_instance = instantiated as Node3D
	_weapon_view_instance.name = "RuntimeWeaponView"
	sway_pivot.add_child(_weapon_view_instance)
	if _weapon_view_instance.get_script() == WEAPON_VIEW_SCRIPT:
		_weapon_view_adapter = _weapon_view_instance
	if definition.auto_play_idle_animation:
		_play_weapon_idle_animation()


func _play_weapon_fire_animation() -> void:
	if _weapon_view_adapter != null and _weapon_view_adapter.has_method("play_fire"):
		_weapon_view_adapter.call("play_fire")
		return
	var definition := _get_weapon_definition()
	if definition != null:
		_play_weapon_animation_by_name(definition.fire_animation)


func _play_weapon_reload_animation() -> void:
	if _weapon_view_adapter != null and _weapon_view_adapter.has_method("play_reload"):
		_weapon_view_adapter.call("play_reload")
		return
	var definition := _get_weapon_definition()
	if definition != null:
		_play_weapon_animation_by_name(definition.reload_animation)


func _play_weapon_dry_fire_animation() -> void:
	if _weapon_view_adapter != null and _weapon_view_adapter.has_method("play_dry_fire"):
		_weapon_view_adapter.call("play_dry_fire")
		return
	var definition := _get_weapon_definition()
	if definition != null:
		_play_weapon_animation_by_name(definition.dry_fire_animation)


func _play_weapon_idle_animation() -> void:
	if _weapon_view_adapter != null and _weapon_view_adapter.has_method("play_idle"):
		_weapon_view_adapter.call("play_idle")
		return
	var definition := _get_weapon_definition()
	if definition != null:
		_play_weapon_animation_by_name(definition.idle_animation)


func _play_weapon_animation_by_name(animation_name_key: StringName) -> void:
	if _weapon_view_instance == null or animation_name_key.is_empty():
		return
	var anim := _weapon_view_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		return
	var animation_name := String(animation_name_key)
	if anim.has_animation(animation_name):
		anim.play(animation_name)
