@tool
## Authoring resource for person runtime defaults, dialogue presentation, and named conversation graphs.
class_name PersonDefinition
extends Resource


@export var role: StringName = &"":
	set(value):
		if role == value:
			return
		role = value
		emit_changed()

@export var speaker_name := "Person":
	set(value):
		if speaker_name == value:
			return
		speaker_name = value
		emit_changed()

@export_group("Visual")
## World 3D billboard sprite texture.
@export var body_texture: Texture2D:
	set(value):
		if body_texture == value:
			return
		body_texture = value
		emit_changed()

@export_range(0.2, 4.0, 0.01) var height_meters := 1.8:
	set(value):
		if is_equal_approx(height_meters, value):
			return
		height_meters = value
		emit_changed()

@export var sprite_scale := Vector3(1.0, 1.0, 1.0):
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

@export_group("Dialogue")
## Default dialogue portrait UI texture.
@export var portrait: Texture2D:
	set(value):
		if portrait == value:
			return
		portrait = value
		emit_changed()

## Expression map linking StringName keys (e.g. &"happy", &"angry", &"surprised") to Texture2D or SpriteFrames.
@export var portraits: Dictionary[String, Texture2D] = {}:
	set(value):
		portraits = value
		emit_changed()
		
## Primary conversation resource.
@export var conversation: DialogueConversation:
	set(value):
		if conversation == value:
			return
		conversation = value
		emit_changed()

## Named conversation map (e.g. {"main": conversation_a, "quest": conversation_b, "vendor": conversation_c}).
@export var conversations: Dictionary[String, DialogueConversation] = {}:
	set(value):
		conversations = value
		emit_changed()
		

## Audio blip played during typewriter text reveal for this character.
@export var voice_blip: AudioStream:
	set(value):
		if voice_blip == value:
			return
		voice_blip = value
		emit_changed()

@export_group("Movement")
@export_range(0.0, 20.0, 0.1) var move_speed_meters_per_sec := 1.5:
	set(value):
		if is_equal_approx(move_speed_meters_per_sec, value):
			return
		move_speed_meters_per_sec = value
		emit_changed()

@export_group("Health")
## Health
@export_range(1.0, 500.0, 1.0) var max_health := 100.0:
	set(value):
		if is_equal_approx(max_health, value):
			return
		max_health = value
		emit_changed()





## Returns a conversation by key from the named conversations map, falling back to the primary conversation.
func get_conversation(key: StringName = &"") -> DialogueConversation:
	if not key.is_empty() and conversations.has(key):
		var found = conversations[key]
		if found is DialogueConversation:
			return found as DialogueConversation
	return conversation


## Returns a portrait for an expression key (e.g. &"happy", &"angry"), falling back to default portrait.
func get_portrait_for_expression(expression_key: StringName = &"") -> Variant:
	if not expression_key.is_empty() and portraits.has(expression_key):
		return portraits[expression_key]
	return portrait
