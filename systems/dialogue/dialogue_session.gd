## Runtime state machine for one active conversation.
## Resolves choices, cross-graph transitions, and effects while containing no UI logic.
class_name DialogueSession
extends RefCounted

signal node_changed(node: DialogueNode)
signal conversation_swapped(conversation: DialogueConversation)
signal ended

var conversation: DialogueConversation
var context: DialogueContext
var current_node: DialogueNode
var active := false
var speaker_definition: PersonDefinition


## Starts at the conversation entry node. Returns false for an empty conversation.
func start(dialogue: DialogueConversation, dialogue_context: DialogueContext, person_def: PersonDefinition = null) -> bool:
	conversation = dialogue
	context = dialogue_context
	speaker_definition = person_def
	var entry_node := conversation.get_entry_node() if conversation else null
	if entry_node == null:
		return false
	active = true
	_enter_node(entry_node)
	return true


func get_available_choices() -> Array[DialogueChoice]:
	return current_node.get_available_choices(context) if active and current_node else []


## Selects by the visible-choice index, applies its effects, and transitions.
func choose(index: int) -> bool:
	var available_choices := get_available_choices()
	if index < 0 or index >= available_choices.size():
		return false
	var selected_choice := available_choices[index]
	selected_choice.apply_effects(context)

	if selected_choice.target_conversation != null:
		return swap_to_conversation(selected_choice.target_conversation, selected_choice.next_node_id)
	elif not selected_choice.target_conversation_id.is_empty() and speaker_definition != null:
		var target := speaker_definition.get_conversation(selected_choice.target_conversation_id)
		if target != null:
			return swap_to_conversation(target, selected_choice.next_node_id)

	return _transition_to(selected_choice.next_node_id)


## Follows the current node's automatic route when no choices are available.
func continue_dialogue() -> bool:
	if not active or current_node == null or not get_available_choices().is_empty():
		return false
	if current_node.target_conversation != null:
		return swap_to_conversation(current_node.target_conversation, current_node.next_node_id)
	elif not current_node.target_conversation_id.is_empty() and speaker_definition != null:
		var target := speaker_definition.get_conversation(current_node.target_conversation_id)
		if target != null:
			return swap_to_conversation(target, current_node.next_node_id)
	return _transition_to(current_node.next_node_id)


## Swaps the active conversation graph to a new DialogueConversation resource.
func swap_to_conversation(next_conversation: DialogueConversation, target_node_id: StringName = &"") -> bool:
	if next_conversation == null:
		finish()
		return false
	conversation = next_conversation
	conversation_swapped.emit(conversation)
	var next_node := conversation.get_node_by_id(target_node_id) if not target_node_id.is_empty() else conversation.get_entry_node()
	if next_node == null:
		push_warning("Swapped dialogue '%s' missing node '%s'." % [conversation.id, target_node_id])
		finish()
		return false
	_enter_node(next_node)
	return true


## Ends the session exactly once and emits ended.
func finish() -> void:
	if not active:
		return
	active = false
	current_node = null
	ended.emit()


func _transition_to(node_id: StringName) -> bool:
	if node_id.is_empty():
		finish()
		return true
	var destination_node := conversation.get_node_by_id(node_id)
	if destination_node == null:
		push_warning("Dialogue '%s' references missing node '%s'." % [conversation.id, node_id])
		finish()
		return false
	_enter_node(destination_node)
	return true


func _enter_node(dialogue_node: DialogueNode) -> void:
	current_node = dialogue_node
	current_node.apply_effects(context)
	node_changed.emit(current_node)
