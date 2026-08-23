extends SceneTree

const PANEL_SCENE := preload("res://features/dialogue/dialogue_panel.tscn")


class TestState extends Node:
	func get_global_flag(_flag: StringName, default_value: Variant = null) -> Variant:
		return default_value

	func set_global_flag(_flag: StringName, _value: Variant) -> void:
		pass


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sound := AudioStreamWAV.new()
	sound.data = PackedByteArray([0, 0, 0, 0])
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 44100
	var profile := DialogueSpeakerProfile.new()
	profile.display_name = "Flavor Test"
	profile.characters_per_second = 1.0
	profile.voice_blip = sound
	profile.minimum_pitch = 0.8
	profile.maximum_pitch = 1.2
	var dialogue_node := DialogueNode.new()
	dialogue_node.id = &"line"
	dialogue_node.text = "Hello!"
	dialogue_node.voice_line = sound
	dialogue_node.blip_during_voice_line = true
	var conversation := DialogueConversation.new()
	conversation.entry_node_id = dialogue_node.id
	conversation.default_speaker_profile = profile
	conversation.nodes = [dialogue_node]

	var panel := PANEL_SCENE.instantiate() as DialoguePanel
	root.add_child(panel)
	var context := DialogueContext.new(null, null, TestState.new())
	var opened := panel.open_dialogue(conversation, context)
	var started_reveal: bool = panel._is_text_revealing and panel.choices_container.get_child_count() == 0
	var voice_assigned: bool = panel.voice_line_player.stream == sound
	panel._play_voice_blip(dialogue_node, profile)
	var blip_configured: bool = panel.blip_player.stream == sound and panel.blip_player.pitch_scale >= 0.8 and panel.blip_player.pitch_scale <= 1.2
	profile.voice_blip = null
	panel._play_voice_blip(dialogue_node, profile)
	var default_blip_configured: bool = panel.blip_player.stream is AudioStreamWAV and panel.blip_player.stream != sound
	panel._complete_text_reveal()
	var skipped_to_responses: bool = not panel._is_text_revealing and panel.text_label.visible_characters == -1 and panel.choices_container.get_child_count() == 1

	if not opened or not started_reveal or not voice_assigned or not blip_configured or not default_blip_configured or not skipped_to_responses:
		push_error("Dialogue flavor regression detected.")
		quit(1)
		return
	quit()