## Manages combat-specific visual feedback (hit markers, health readout, damage flashes).
class_name CombatHUDController
extends Node

const COMBAT_FEEDBACK_DURATION := 0.22
const DAMAGE_FLASH_MAX_ALPHA := 0.75
const DAMAGE_FLASH_INCREMENT := 0.3
const DAMAGE_FLASH_DECAY_PER_SEC := 2.4
const CROSSHAIR_DEFAULT_COLOR := Color(1, 1, 1, 1)
const CROSSHAIR_HIT_COLOR := Color(1, 0.38, 0.2, 1)

var crosshair: Label
var combat_feedback: Label
var health_readout: Label
var damage_flash: ColorRect

var _player_weapon_component: PlayerWeaponComponent
var _player_health_component: ActorHealthComponent
var _combat_feedback_tween: Tween
var _damage_flash_tween: Tween


func setup_nodes(p_crosshair: Label, p_combat_feedback: Label, p_health_readout: Label, p_damage_flash: ColorRect) -> void:
	crosshair = p_crosshair
	combat_feedback = p_combat_feedback
	health_readout = p_health_readout
	damage_flash = p_damage_flash
	_update_health_readout()


func bind_player_combat_signals(player: Player) -> void:
	var next_weapon := player.get_node_or_null("PlayerWeaponComponent") as PlayerWeaponComponent if player else null
	if _player_weapon_component != null and _player_weapon_component != next_weapon:
		if _player_weapon_component.weapon_fired.is_connected(_on_player_weapon_fired):
			_player_weapon_component.weapon_fired.disconnect(_on_player_weapon_fired)
		if _player_weapon_component.dry_fired.is_connected(_on_player_weapon_dry_fired):
			_player_weapon_component.dry_fired.disconnect(_on_player_weapon_dry_fired)
	_player_weapon_component = next_weapon
	if _player_weapon_component != null:
		if not _player_weapon_component.weapon_fired.is_connected(_on_player_weapon_fired):
			_player_weapon_component.weapon_fired.connect(_on_player_weapon_fired)
		if not _player_weapon_component.dry_fired.is_connected(_on_player_weapon_dry_fired):
			_player_weapon_component.dry_fired.connect(_on_player_weapon_dry_fired)

	var next_health := player.get_node_or_null("ActorHealthComponent") as ActorHealthComponent if player else null
	if _player_health_component != null and _player_health_component != next_health:
		if _player_health_component.damaged.is_connected(_on_player_damaged):
			_player_health_component.damaged.disconnect(_on_player_damaged)
		if _player_health_component.health_changed.is_connected(_on_player_health_changed):
			_player_health_component.health_changed.disconnect(_on_player_health_changed)
	_player_health_component = next_health
	if _player_health_component != null:
		if not _player_health_component.damaged.is_connected(_on_player_damaged):
			_player_health_component.damaged.connect(_on_player_damaged)
		if not _player_health_component.health_changed.is_connected(_on_player_health_changed):
			_player_health_component.health_changed.connect(_on_player_health_changed)
	
	_update_health_readout()


func _show_combat_feedback(text: String, color: Color) -> void:
	if combat_feedback:
		combat_feedback.text = text
		combat_feedback.modulate = color
		combat_feedback.visible = true
	if _combat_feedback_tween != null:
		_combat_feedback_tween.kill()
	_combat_feedback_tween = create_tween()
	if crosshair:
		crosshair.modulate = color
		_combat_feedback_tween.tween_property(crosshair, "modulate", CROSSHAIR_DEFAULT_COLOR, COMBAT_FEEDBACK_DURATION)
	else:
		_combat_feedback_tween.tween_interval(COMBAT_FEEDBACK_DURATION)
	_combat_feedback_tween.tween_callback(_hide_combat_feedback_text)


func _hide_combat_feedback_text() -> void:
	if combat_feedback:
		combat_feedback.visible = false


func _on_player_weapon_fired(hit: bool, _hit_position: Vector3, _ammo_in_mag: int, _ammo_reserve: int) -> void:
	if hit:
		_show_combat_feedback("HIT", CROSSHAIR_HIT_COLOR)
	else:
		_show_combat_feedback("MISS", CROSSHAIR_DEFAULT_COLOR)


func _on_player_weapon_dry_fired(_ammo_in_mag: int, _ammo_reserve: int) -> void:
	_show_combat_feedback("EMPTY", Color(1, 0.85, 0.4, 1))


func _on_player_damaged(amount: float, _source: Node) -> void:
	if amount <= 0.0:
		return
	_flash_damage()
	_show_combat_feedback("-%d HP" % int(round(amount)), Color(1, 0.45, 0.4, 1))


func _flash_damage() -> void:
	if damage_flash == null:
		return
	if _damage_flash_tween != null:
		_damage_flash_tween.kill()
	var next_alpha := minf(DAMAGE_FLASH_MAX_ALPHA, damage_flash.modulate.a + DAMAGE_FLASH_INCREMENT)
	damage_flash.modulate.a = next_alpha
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(damage_flash, "modulate:a", 0.0, next_alpha / DAMAGE_FLASH_DECAY_PER_SEC)


func _on_player_health_changed(current_health: float, max_health: float) -> void:
	if health_readout:
		health_readout.text = "HP %d/%d" % [int(round(current_health)), int(round(max_health))]


func _update_health_readout() -> void:
	if health_readout == null:
		return
	if _player_health_component == null:
		health_readout.text = "HP --"
		return
	_on_player_health_changed(_player_health_component.current_health, _player_health_component.max_health)
