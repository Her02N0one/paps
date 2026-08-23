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
	var choice := DialogueChoice.new()
	choice.text = "Ask a question"
	choice.next_node_id = &"answer"
	var opening := DialogueNode.new()
	opening.id = &"opening"
	opening.speaker = "Mara"
	opening.text = "What do you need?"
	opening.choices = [choice]
	var answer := DialogueNode.new()
	answer.id = &"answer"
	answer.speaker = "Mara"
	answer.text = "That is the answer."
	var conversation := DialogueConversation.new()
	conversation.entry_node_id = opening.id
	conversation.nodes = [opening, answer]

	var panel := PANEL_SCENE.instantiate() as DialoguePanel
	var close_events: Array = []
	panel.closed.connect(func(): close_events.append(true))
	root.add_child(panel)
	var context := DialogueContext.new(null, null, TestState.new())
	var opened := panel.open_dialogue(conversation, context)
	var opening_rendered: bool = panel.speaker_label.text == "Mara" and panel.choices_container.get_child_count() == 1
	panel.session.choose(0)
	var answer_rendered: bool = panel.text_label.text == "That is the answer."
	panel.session.continue_dialogue()
	var completed: bool = not panel.visible and close_events.size() == 1

	if not opened or not opening_rendered or not answer_rendered or not completed:
		push_error("Dialogue panel integration regression detected.")
		quit(1)
		return
	quit()