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

	# Build Graph B (target)
	var node_b := DialogueNode.new()
	node_b.id = &"graph_b_start"
	node_b.speaker = "Jerry"
	node_b.text = "Welcome to graph B!"
	node_b.expression = &"surprised"
	var graph_b := DialogueConversation.new()
	graph_b.id = &"graph_b"
	graph_b.entry_node_id = &"graph_b_start"
	graph_b.nodes = [node_b]

	# Build Choice jumping to Graph B
	var jump_choice := DialogueChoice.new()
	jump_choice.text = "Jump to Graph B"
	jump_choice.target_conversation = graph_b

	# Build Graph A (entry)
	var node_a := DialogueNode.new()
	node_a.id = &"graph_a_start"
	node_a.speaker = "Jerry"
	node_a.text = "Hello from graph A!"
	node_a.choices = [jump_choice]
	var graph_a := DialogueConversation.new()
	graph_a.id = &"graph_a"
	graph_a.entry_node_id = &"graph_a_start"
	graph_a.nodes = [node_a]

	# Build PersonDefinition
	var def := PersonDefinition.new()
	def.speaker_name = "Jerry"
	def.conversation = graph_a
	def.conversations = {
		&"a": graph_a,
		&"b": graph_b
	}

	var session := DialogueSession.new()
	var started := session.start(graph_a, context, def)
	var initial_node_ok: bool = session.current_node == node_a
	
	# Choose jump choice to Graph B
	var swapped := session.choose(0)
	var graph_swapped_ok: bool = swapped and session.conversation == graph_b and session.current_node == node_b

	if not started or not initial_node_ok or not graph_swapped_ok:
		push_error("Dialogue cross-conversation swapping regression detected.")
		quit(1)
		return
	quit()
