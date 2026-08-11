class_name NewGameSpawnPoint
extends Marker3D

@export var marker_id: StringName

@export_group("Debug Player Start")
@export var apply_debug_overrides := false
@export var starter_weapon: Resource
@export var refill_weapon_ammo := true
@export_range(-1.0, 500.0, 1.0) var starting_health := -1.0
@export var refill_health_to_max := false


func _ready() -> void:
	add_to_group("new_game_spawn_points")


func apply_debug_player_start(player: Node) -> void:
	if not apply_debug_overrides or player == null:
		return
	if starter_weapon != null:
		var weapon_component := player.get_node_or_null("PlayerWeaponComponent")
		if weapon_component != null and weapon_component.has_method("equip_weapon"):
			weapon_component.call("equip_weapon", starter_weapon, refill_weapon_ammo)
	if starting_health >= 0.0 or refill_health_to_max:
		var health_component := player.get_node_or_null("ActorHealthComponent")
		if health_component != null and health_component.has_method("set_max_health"):
			var max_health := float(health_component.get("max_health"))
			if starting_health >= 0.0:
				health_component.call("set_max_health", maxf(starting_health, 1.0), true)
			elif refill_health_to_max:
				health_component.call("set_max_health", maxf(max_health, 1.0), true)
