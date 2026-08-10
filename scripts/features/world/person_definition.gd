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
