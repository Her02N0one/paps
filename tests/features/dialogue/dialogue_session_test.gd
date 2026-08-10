extends SceneTree


class TestState extends Node:
	var flags: Dictionary = {}

	func get_global_flag(flag: StringName, default_value: Variant = null) -> Variant:
		return flags.get(flag, default_value)

	func set_global_flag(flag: StringName, value: Variant) -> void:
		flags[flag] = value


func _initialize() -> void:
	var state := TestState.new()
	var context := DialogueContext.new(null, null, state)

	var unlock_condition := DialogueFlagCondition.new()
	unlock_condition.flag = &"knows_code"
	unlock_condition.expected_value = true
	var chose_secret_effect := DialogueSetFlagEffect.new()
	chose_secret_effect.flag = &"chose_secret"
	var visited_effect := DialogueSetFlagEffect.new()
	visited_effect.flag = &"visited_secret"

	var ordinary_choice := DialogueChoice.new()
	ordinary_choice.text = "Goodbye"
	var secret_choice := DialogueChoice.new()
	secret_choice.text = "Use the code"
	secret_choice.next_node_id = &"secret"
	secret_choice.conditions = [unlock_condition]
	secret_choice.effects = [chose_secret_effect]

	var entry := DialogueNode.new()
	entry.id = &"start"
	entry.choices = [ordinary_choice, secret_choice]
	var secret := DialogueNode.new()
	secret.id = &"secret"
	secret.text = "The door opens."
	secret.effects = [visited_effect]

	var conversation := DialogueConversation.new()
	conversation.id = &"test_conversation"
	conversation.entry_node_id = &"start"
	conversation.nodes = [entry, secret]

	var session := DialogueSession.new()
	var started := session.start(conversation, context)
	var hidden_choice_filtered: bool = session.get_available_choices().size() == 1
	context.set_flag(&"knows_code", true)
	var choice_unlocked: bool = session.get_available_choices().size() == 2
	var transitioned: bool = session.choose(1) and session.current_node == secret
	var effects_applied: bool = state.flags.get(&"chose_secret") == true and state.flags.get(&"visited_secret") == true
	var completed: bool = session.continue_dialogue() and not session.active

	if not started or not hidden_choice_filtered or not choice_unlocked or not transitioned or not effects_applied or not completed:
		push_error("Dialogue session regression detected.")
		quit(1)
		return
	quit()