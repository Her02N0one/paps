## Presents a DialogueSession as typewriter text, voice audio, portraits, and choices.
## Conversation rules remain in resources and DialogueSession, not in this UI class.
@tool
class_name DialoguePanel
extends GamePanel

const DEFAULT_BLIP_FREQUENCY := 660.0
const DEFAULT_BLIP_DURATION := 0.025
const DEFAULT_BLIP_MIX_RATE := 22050

@onready var speaker_label: Label = %Speaker
@onready var text_label: RichTextLabel = %DialogueText
@onready var portrait: TextureRect = %Portrait
@onready var choices_container: VBoxContainer = %Choices
@onready var voice_line_player: AudioStreamPlayer = %VoiceLinePlayer
@onready var blip_player: AudioStreamPlayer = %VoiceBlipPlayer

var session: DialogueSession
# Monotonic token used to cancel older async reveal loops when a new node is shown.
var _reveal_generation := 0
var _is_text_revealing := false
var _displayed_node: DialogueNode
var _default_voice_blip: AudioStreamWAV


## Creates a fresh session and displays it. Returns false when no entry node exists.
func open_dialogue(conversation: DialogueConversation, context: DialogueContext) -> bool:
	_release_dialogue_session()
	session = DialogueSession.new()
	session.node_changed.connect(_show_node)
	session.ended.connect(_on_session_ended)
	# Reject conversations that cannot resolve an entry node.
	if not session.start(conversation, context):
		_release_dialogue_session()
		return false
	visible = true
	opened.emit()
	return true


## Stops presentation and audio, ends the active session, and emits closed.
func close_panel() -> void:
	# No-op when already closed so callers can close defensively.
	if not visible:
		return
	visible = false
	_stop_node_presentation()
	# Active session must be finished to fire DialogueSession cleanup hooks.
	if session and session.active:
		# Prevent recursive close path by disconnecting ended callback before finish().
		if session.ended.is_connected(_on_session_ended):
			session.ended.disconnect(_on_session_ended)
		session.finish()
	_clear_choices()
	_release_dialogue_session()
	closed.emit()


func _show_node(dialogue_node: DialogueNode) -> void:
	_stop_node_presentation()
	_displayed_node = dialogue_node
	var profile := _resolve_speaker_profile(dialogue_node)
	# Per-node profile overrides conversation defaults when present.
	speaker_label.text = profile.display_name if profile and not profile.display_name.is_empty() else dialogue_node.speaker
	speaker_label.modulate = profile.name_color if profile else Color.WHITE
	text_label.text = dialogue_node.text
	text_label.modulate = profile.text_color if profile else Color.WHITE
	portrait.texture = profile.portrait if profile else null
	portrait.visible = portrait.texture != null
	_clear_choices()
	_play_voice_line(dialogue_node)
	# Typewriter reveal runs only when profile speed is positive and node is not instant.
	if profile and profile.characters_per_second > 0.0 and not dialogue_node.instant_text:
		_reveal_text_over_time(dialogue_node, profile, _reveal_generation)
	else:
		# Instant path reveals full text and builds response buttons right away.
		text_label.visible_characters = -1
		_build_response_buttons(dialogue_node)


func _reveal_text_over_time(
	dialogue_node: DialogueNode,
	profile: DialogueSpeakerProfile,
	reveal_generation: int
) -> void:
	_is_text_revealing = true
	text_label.visible_characters = 0
	var plain_text := text_label.get_parsed_text()
	var character_delay := 1.0 / (profile.characters_per_second * dialogue_node.text_speed_multiplier)
	var non_whitespace_characters := 0
	for index in plain_text.length():
		# A new node or a skip increments the generation, invalidating this async reveal.
		if reveal_generation != _reveal_generation:
			return
		var character := plain_text[index]
		text_label.visible_characters = index + 1
		# Only voiced characters trigger blips; whitespace is silent.
		if not character.is_empty() and not character.strip_edges().is_empty():
			non_whitespace_characters += 1
			# Emit a blip every N spoken characters based on speaker profile.
			if non_whitespace_characters % profile.blip_every_characters == 0:
				_play_voice_blip(dialogue_node, profile)
		var delay := character_delay + _get_punctuation_pause(character, dialogue_node, profile)
		await get_tree().create_timer(delay, true).timeout
	# Complete only if this reveal loop is still the latest generation.
	if reveal_generation == _reveal_generation:
		_complete_text_reveal()


func _complete_text_reveal() -> void:
	# Guard duplicate completion calls from input skip and timer race.
	if not _is_text_revealing:
		return
	_reveal_generation += 1
	_is_text_revealing = false
	text_label.visible_characters = -1
	_build_response_buttons(_displayed_node)


func _build_response_buttons(dialogue_node: DialogueNode) -> void:
	var available_choices := session.get_available_choices()
	if available_choices.is_empty():
		# No visible choices means we expose the implicit path: continue or leave.
		_add_button("Continue" if not dialogue_node.next_node_id.is_empty() else "Leave", session.continue_dialogue)
	else:
		for index in available_choices.size():
			# Bind the filtered index from this rendered list, not authored absolute position.
			_add_button(available_choices[index].text, session.choose.bind(index))


func _resolve_speaker_profile(dialogue_node: DialogueNode) -> DialogueSpeakerProfile:
	# Node-specific profile overrides conversation default profile.
	if dialogue_node.speaker_profile:
		return dialogue_node.speaker_profile
	return session.conversation.default_speaker_profile if session and session.conversation else null


func _play_voice_line(dialogue_node: DialogueNode) -> void:
	voice_line_player.stop()
	# Silent nodes intentionally skip voice playback.
	if dialogue_node.voice_line == null:
		return
	voice_line_player.stream = dialogue_node.voice_line
	voice_line_player.volume_db = dialogue_node.voice_line_volume_db
	voice_line_player.pitch_scale = 1.0
	voice_line_player.play()


func _play_voice_blip(dialogue_node: DialogueNode, profile: DialogueSpeakerProfile) -> void:
	# Some nodes deliberately disable blips for effect.
	if not dialogue_node.use_voice_blips:
		return
	# Optionally suppress blips while full voice line is playing.
	if voice_line_player.playing and not dialogue_node.blip_during_voice_line:
		return
	var pitch_range := profile.get_pitch_range()
	blip_player.stream = profile.voice_blip if profile.voice_blip else _get_default_voice_blip()
	blip_player.volume_db = profile.blip_volume_db
	blip_player.pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	blip_player.play()


func _get_default_voice_blip() -> AudioStreamWAV:
	# Reuse generated waveform to avoid rebuilding sample data every node.
	if _default_voice_blip:
		return _default_voice_blip
	# Generate a tiny decaying sine beep so dialogue works without an authored audio asset.
	var sample_count := int(DEFAULT_BLIP_DURATION * DEFAULT_BLIP_MIX_RATE)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for index in sample_count:
		var fade := 1.0 - float(index) / sample_count
		var wave := sin(TAU * DEFAULT_BLIP_FREQUENCY * index / DEFAULT_BLIP_MIX_RATE)
		var sample := int(wave * fade * 5000.0)
		samples.encode_s16(index * 2, sample)
	_default_voice_blip = AudioStreamWAV.new()
	_default_voice_blip.format = AudioStreamWAV.FORMAT_16_BITS
	_default_voice_blip.mix_rate = DEFAULT_BLIP_MIX_RATE
	_default_voice_blip.stereo = false
	_default_voice_blip.data = samples
	return _default_voice_blip


func _get_punctuation_pause(character: String, dialogue_node: DialogueNode, profile: DialogueSpeakerProfile) -> float:
	# Sentence punctuation gets longer pause than commas for natural cadence.
	if character in [".", "!", "?"]:
		return profile.sentence_pause * dialogue_node.punctuation_pause_multiplier
	# Mid-sentence punctuation uses shorter pause profile.
	if character in [",", ";", ":"]:
		return profile.comma_pause * dialogue_node.punctuation_pause_multiplier
	return 0.0


func _gui_input(event: InputEvent) -> void:
	# Skip gesture only applies while reveal is active and skip is allowed.
	if not _is_text_revealing or _displayed_node == null or not _displayed_node.allow_skip:
		return
	# Skip accepts both keyboard confirm and primary click for parity across control schemes.
	if event.is_action_pressed("ui_accept") or event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_complete_text_reveal()


func _add_button(button_text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = button_text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	choices_container.add_child(button)
	if choices_container.get_child_count() == 1:
		_focus_button.call_deferred(button)


func _focus_button(button: Button) -> void:
	# Defer focus until button is in tree and still valid.
	if is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()


func _clear_choices() -> void:
	# Remove existing choice widgets before creating next-node responses.
	for child in choices_container.get_children():
		choices_container.remove_child(child)
		child.queue_free()


func _on_session_ended() -> void:
	close_panel()


func _stop_node_presentation() -> void:
	_reveal_generation += 1
	_is_text_revealing = false
	_displayed_node = null
	voice_line_player.stop()
	blip_player.stop()


func _release_dialogue_session() -> void:
	# Nothing to release when no session is active.
	if session == null:
		return
	# Disconnect both signals so old sessions cannot drive this panel.
	if session.node_changed.is_connected(_show_node):
		session.node_changed.disconnect(_show_node)
	if session.ended.is_connected(_on_session_ended):
		session.ended.disconnect(_on_session_ended)
	session = null
