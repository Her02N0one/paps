@tool
## Authoring resource for person runtime defaults and dialogue presentation.
class_name PersonDefinition
extends Resource

@export var speaker_name := "Person":
	set(value):
		if speaker_name == value:
			return
		# emit_changed keeps editor previews and tool adapters synchronized.
		speaker_name = value
		emit_changed()

@export_multiline var opening_text := "Hello.":
	set(value):
		if opening_text == value:
			return
		opening_text = value
		emit_changed()

@export var conversation: DialogueConversation:
	set(value):
		if conversation == value:
			return
		conversation = value
		emit_changed()

@export var portrait_texture: Texture2D:
	set(value):
		if portrait_texture == value:
			return
		portrait_texture = value
		emit_changed()

@export_range(0.2, 4.0, 0.01) var height_meters := 1.8:
	set(value):
		if is_equal_approx(height_meters, value):
			return
		height_meters = value
		emit_changed()

@export var sprite_scale := Vector3(0.13, 0.13, 0.13):
	set(value):
		if sprite_scale.is_equal_approx(value):
			return
		sprite_scale = value
		emit_changed()

@export var sprite_tint: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		if sprite_tint == value:
			return
		sprite_tint = value
		emit_changed()

@export_range(1.0, 500.0, 1.0) var max_health := 100.0:
	set(value):
		if is_equal_approx(max_health, value):
			return
		max_health = value
		emit_changed()

@export_range(0.0, 100.0, 0.1) var base_damage := 10.0:
	set(value):
		if is_equal_approx(base_damage, value):
			return
		base_damage = value
		emit_changed()

@export_range(0.1, 20.0, 0.1) var attack_range_meters := 2.0:
	set(value):
		if is_equal_approx(attack_range_meters, value):
			return
		attack_range_meters = value
		emit_changed()

@export_range(0.1, 10.0, 0.1) var attack_cooldown_seconds := 1.0:
	set(value):
		if is_equal_approx(attack_cooldown_seconds, value):
			return
		attack_cooldown_seconds = value
		emit_changed()

@export_range(0.0, 20.0, 0.1) var move_speed_meters_per_sec := 3.5:
	set(value):
		if is_equal_approx(move_speed_meters_per_sec, value):
			return
		move_speed_meters_per_sec = value
		emit_changed()

@export_range(0.5, 50.0, 0.1) var combat_engage_distance_meters := 8.0:
	set(value):
		if is_equal_approx(combat_engage_distance_meters, value):
			return
		combat_engage_distance_meters = value
		emit_changed()

@export_range(0.5, 50.0, 0.1) var combat_disengage_distance_meters := 12.0:
	set(value):
		if is_equal_approx(combat_disengage_distance_meters, value):
			return
		combat_disengage_distance_meters = value
		emit_changed()
