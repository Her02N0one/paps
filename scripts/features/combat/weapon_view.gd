## View-layer weapon instance: drives model animation hooks for fire/reload/idle.
class_name WeaponView
extends Node3D

@export var animation_player_path: NodePath = NodePath("AnimationPlayer")
@export var idle_animation: StringName = &"idle"
@export var fire_animation: StringName = &"fire"
@export var reload_animation: StringName = &"reload"
@export var dry_fire_animation: StringName = &"dry_fire"

var _anim: AnimationPlayer
var _base_position := Vector3.ZERO
var _fallback_tween: Tween


func _ready() -> void:
	_base_position = position
	_anim = get_node_or_null(animation_player_path) as AnimationPlayer


func play_idle() -> void:
	if _play_animation_if_present(idle_animation):
		return


func play_fire() -> void:
	if _play_animation_if_present(fire_animation):
		return
	_play_fallback_kick(0.05, 0.02, 0.07)


func play_reload() -> void:
	if _play_animation_if_present(reload_animation):
		return
	_play_fallback_reload_motion()


func play_dry_fire() -> void:
	if _play_animation_if_present(dry_fire_animation):
		return
	_play_fallback_kick(0.015, 0.01, 0.05)


func _play_animation_if_present(animation_name_key: StringName) -> bool:
	if _anim == null or animation_name_key.is_empty():
		return false
	var name_string := String(animation_name_key)
	if not _anim.has_animation(name_string):
		return false
	_anim.play(name_string)
	return true


func _play_fallback_kick(backward: float, side: float, duration: float) -> void:
	if _fallback_tween != null:
		_fallback_tween.kill()
	var side_sign := -1.0 if randi() % 2 == 0 else 1.0
	_fallback_tween = create_tween()
	_fallback_tween.tween_property(self, "position", _base_position + Vector3(side * side_sign, -side * 0.4, backward), duration * 0.35)
	_fallback_tween.tween_property(self, "position", _base_position, duration * 0.65)


func _play_fallback_reload_motion() -> void:
	if _fallback_tween != null:
		_fallback_tween.kill()
	_fallback_tween = create_tween()
	_fallback_tween.tween_property(self, "rotation_degrees", Vector3(-8.0, 0.0, 10.0), 0.11)
	_fallback_tween.tween_property(self, "rotation_degrees", Vector3(7.0, 0.0, -8.0), 0.13)
	_fallback_tween.tween_property(self, "rotation_degrees", Vector3.ZERO, 0.16)
