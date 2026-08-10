## Authored conversation graph containing every node and its starting point.
## Runtime traversal belongs to DialogueSession; this resource only stores data.
class_name DialogueConversation
extends Resource

@export var id: StringName
@export var entry_node_id: StringName
@export var default_speaker_profile: DialogueSpeakerProfile
@export var nodes: Array[DialogueNode] = []


## Returns the configured entry node, or the first node when no entry ID is set.
func get_entry_node() -> DialogueNode:
	# Explicit entry IDs make node ordering editorial only; first-node fallback keeps small conversations quick to author.
	if not entry_node_id.is_empty():
		return get_node_by_id(entry_node_id)
	return nodes[0] if not nodes.is_empty() else null


## Finds a node by its conversation-local ID.
func get_node_by_id(node_id: StringName) -> DialogueNode:
	for dialogue_node in nodes:
		if dialogue_node and dialogue_node.id == node_id:
			return dialogue_node
	return null