## Reusable visual and vocal flavor for a speaker.
## Assign at conversation level for defaults or node level for a temporary override.
class_name DialogueSpeakerProfile
extends Resource

@export var display_name := ""
@export var portrait: Texture2D
@export var name_color := Color.WHITE
@export var text_color := Color.WHITE

@export_group("Text Delivery")
@export_range(0.0, 120.0, 1.0) var characters_per_second := 35.0
@export_range(0.0, 1.0, 0.01) var comma_pause := 0.08
@export_range(0.0, 2.0, 0.01) var sentence_pause := 0.2

@export_group("Voice Blips")
@export var voice_blip: AudioStream
@export_range(1, 12, 1) var blip_every_characters := 2
@export_range(0.1, 4.0, 0.01) var minimum_pitch := 0.95
@export_range(0.1, 4.0, 0.01) var maximum_pitch := 1.05
@export_range(-40.0, 6.0, 0.5) var blip_volume_db := -6.0


## Returns an ordered range even if the inspector values were entered backwards.
func get_pitch_range() -> Vector2:
	return Vector2(minf(minimum_pitch, maximum_pitch), maxf(minimum_pitch, maximum_pitch))