## One spoken beat in a conversation, including presentation, outgoing choices,
## automatic continuation, and effects applied when the node is entered.
class_name DialogueNode
extends Resource

@export var id: StringName
@export var speaker := ""
@export_multiline var text := ""
@export var speaker_profile: DialogueSpeakerProfile

@export_group("Presentation")
## Expression key (e.g. &"happy", &"angry") resolved against the speaker's PersonDefinition.portraits.
@export var expression: StringName
## Direct portrait texture override for this specific line.
@export var portrait_override: Texture2D

@export_group("Performance")
@export var voice_line: AudioStream
@export_range(-40.0, 6.0, 0.5) var voice_line_volume_db := 0.0
@export var use_voice_blips := true
@export var blip_during_voice_line := false
@export var instant_text := false
@export var allow_skip := true
@export_range(0.1, 4.0, 0.05) var text_speed_multiplier := 1.0
@export_range(0.0, 4.0, 0.05) var punctuation_pause_multiplier := 1.0

@export_group("Flow")
@export var next_node_id: StringName
## Optional target conversation graph resource to jump to automatically.
@export var target_conversation: DialogueConversation
## Optional target conversation key in the speaker's named conversations map to jump to.
@export var target_conversation_id: StringName
@export var choices: Array[DialogueChoice] = []
@export var effects: Array[DialogueEffect] = []


## Returns choices whose conditions all pass in the current gameplay context.
func get_available_choices(context: DialogueContext) -> Array[DialogueChoice]:
	var available: Array[DialogueChoice] = []
	for choice in choices:
		if choice and choice.is_available(context):
			available.append(choice)
	return available


## Applies entry effects in authored order before the node is presented.
func apply_effects(context: DialogueContext) -> void:
	for effect in effects:
		if effect:
			effect.apply(context)