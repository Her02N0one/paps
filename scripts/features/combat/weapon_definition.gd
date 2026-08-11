@tool
## Authoring data for one player-usable hitscan weapon.
class_name WeaponDefinition
extends Resource

@export var display_name := "Starter Blaster"
@export var view_scene: PackedScene
@export var auto_play_idle_animation := true
@export var idle_animation: StringName = &"idle"
@export var fire_animation: StringName = &"fire"
@export var reload_animation: StringName = &"reload"
@export var dry_fire_animation: StringName = &"dry_fire"
@export_range(1, 200, 1) var magazine_size := 12
@export_range(0, 500, 1) var reserve_ammo := 48
@export_range(0.5, 30.0, 0.1) var shots_per_second := 5.5
@export_range(0.0, 10.0, 0.05) var reload_seconds := 1.1
@export_range(0.0, 200.0, 0.1) var damage_per_shot := 18.0
@export_range(1.0, 2000.0, 1.0) var range_meters := 80.0
@export_range(1, 20, 1) var pellets_per_shot := 1
@export_range(0.0, 25.0, 0.01) var spread_degrees := 0.9
@export_range(0.0, 0.2, 0.001) var recoil_push_meters := 0.045
@export_range(0.0, 12.0, 0.01) var recoil_pitch_degrees := 1.2
@export_range(0.0, 8.0, 0.01) var fov_kick_degrees := 0.5
