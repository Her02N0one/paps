@tool
## Authored conversation graph containing every node and its starting point.
## Runtime traversal belongs to DialogueSession; this resource only stores data.
class_name DialogueConversation
extends Resource

@export_group("Compiler")
@export_file("*.txt") var source_file: String
@export var compile_now: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_compile()

@export_group("Data")
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


func _compile() -> void:
	if source_file.is_empty() or not FileAccess.file_exists(source_file):
		push_error("DialogueConversation: source_file is missing or invalid.")
		return
		
	var file = FileAccess.open(source_file, FileAccess.READ)
	if not file:
		push_error("DialogueConversation: failed to read source file.")
		return
		
	var lines = file.get_as_text().split("\n")
	
	# 1. Build map of existing nodes to preserve their inspector additions (audio, effects)
	var old_nodes_map: Dictionary = {}
	for n in nodes:
		if n and not n.id.is_empty():
			old_nodes_map[n.id] = n
			
	var new_nodes_list: Array[DialogueNode] = []
	var parsed_node_ids: Dictionary = {}
	
	var current_node: DialogueNode = null
	var is_first_node := true
	
	for line_idx in range(lines.size()):
		var raw_line = lines[line_idx].strip_edges()
		if raw_line.is_empty() or raw_line.begins_with("#") or raw_line.begins_with("//"):
			continue
			
		# New Node Block [node_id]
		if raw_line.begins_with("[") and raw_line.ends_with("]"):
			var node_id = raw_line.substr(1, raw_line.length() - 2).strip_edges()
			
			if parsed_node_ids.has(node_id):
				push_error("DialogueConversation: Duplicate node ID '[%s]'" % node_id)
				continue
				
			parsed_node_ids[node_id] = true
			
			if old_nodes_map.has(node_id):
				current_node = old_nodes_map[node_id]
			else:
				current_node = DialogueNode.new()
				current_node.id = node_id
				
			if is_first_node:
				entry_node_id = node_id
				is_first_node = false
				
			new_nodes_list.append(current_node)
			
			# Reset text properties so deleted lines in the txt actually get cleared
			current_node.text = ""
			current_node.speaker = ""
			current_node.expression = &""
			current_node.next_node_id = &""
			
			# Store parsed choices temporarily to merge them later
			current_node.set_meta("parsed_choices", [])
			continue
			
		if current_node == null:
			continue
			
		var split_idx = raw_line.find("=")
		if split_idx != -1:
			var key = raw_line.substr(0, split_idx).strip_edges().to_lower()
			var value = raw_line.substr(split_idx + 1).strip_edges()
			
			match key:
				"speaker": current_node.speaker = value
				"expression": current_node.expression = value
				"text": current_node.text = value.replace("\\n", "\n")
				"next": current_node.next_node_id = value
				"choice":
					var choice_parts = value.split("->")
					var c_text = choice_parts[0].strip_edges() if choice_parts.size() >= 1 else ""
					var c_target = choice_parts[1].strip_edges() if choice_parts.size() >= 2 else ""
					
					var parsed_choices: Array = current_node.get_meta("parsed_choices")
					parsed_choices.append({"text": c_text, "target": c_target})
					current_node.set_meta("parsed_choices", parsed_choices)
					
	# 2. Merge choices non-destructively
	for n in new_nodes_list:
		var parsed_choices: Array = n.get_meta("parsed_choices")
		n.remove_meta("parsed_choices")
		
		var old_choices = n.choices.duplicate()
		var new_choices: Array[DialogueChoice] = []
		
		for pc in parsed_choices:
			var matched_choice: DialogueChoice = null
			# Try to find a matching choice by target_id or text
			for oc in old_choices:
				if oc and (oc.next_node_id == pc["target"] or oc.text == pc["text"]):
					matched_choice = oc
					old_choices.erase(oc) # consume it
					break
					
			if matched_choice == null:
				matched_choice = DialogueChoice.new()
				
			matched_choice.text = pc["text"]
			matched_choice.next_node_id = pc["target"]
			new_choices.append(matched_choice)
			
		n.choices = new_choices
		
	# 3. Finalize and clean up stale nodes
	self.nodes = new_nodes_list
	print("DialogueConversation: Compiled %d nodes from %s" % [new_nodes_list.size(), source_file])
	emit_changed()
