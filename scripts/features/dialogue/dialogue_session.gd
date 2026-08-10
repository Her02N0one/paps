## Runtime state machine for one active conversation.
## Resolves choices and effects but deliberately contains no UI logic.
class_name DialogueSession
extends RefCounted

signal node_changed(node: DialogueNode)
signal ended

var conversation: DialogueConversation
var context: DialogueContext
var current_node: DialogueNode
var active := false


## Starts at the conversation entry node. Returns false for an empty conversation.
func start(dialogue: DialogueConversation, dialogue_context: DialogueContext) -> bool:
	conversation = dialogue
	context = dialogue_context
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
	# Indices are validated against currently visible choices after condition filtering.
	if index < 0 or index >= available_choices.size():
		return false
	var selected_choice := available_choices[index]
	selected_choice.apply_effects(context)
	return _transition_to(selected_choice.next_node_id)


## Follows the current node's automatic route when no choices are available.
func continue_dialogue() -> bool:
	# Continue is only valid when the node has no available explicit choices.
	if not active or current_node == null or not get_available_choices().is_empty():
		return false
	return _transition_to(current_node.next_node_id)


## Ends the session exactly once and emits ended.
func finish() -> void:
	if not active:
		return
	active = false
	current_node = null
	ended.emit()


func _transition_to(node_id: StringName) -> bool:
	# An empty destination is an intentional conversation ending, not a missing node.
	if node_id.is_empty():
		finish()
		return true
	var destination_node := conversation.get_node_by_id(node_id)
	if destination_node == null:
		# Missing references are treated as safe termination instead of crashing traversal.
		push_warning("Dialogue '%s' references missing node '%s'." % [conversation.id, node_id])
		finish()
		return false
	_enter_node(destination_node)
	return true


func _enter_node(dialogue_node: DialogueNode) -> void:
	current_node = dialogue_node
	# Effects run first so the UI and newly available choices see the updated state.
	current_node.apply_effects(context)
	node_changed.emit(current_node)