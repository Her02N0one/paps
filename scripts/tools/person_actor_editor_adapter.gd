@tool
## Editor-only adapter that reapplies PersonActor definition changes while authoring.
class_name PersonActorEditorAdapter
extends RefCounted

var _actor: Node
var _last_definition_stamp := ""


func enter_editor_mode(actor: Node) -> void:
	_actor = actor
	if _actor == null:
		return
	_actor.set_process(true)
	_actor.call("_apply_definition_to_children")
	_last_definition_stamp = _build_definition_stamp()


func on_definition_changed() -> void:
	if not Engine.is_editor_hint():
		return
	_last_definition_stamp = _build_definition_stamp()


func tick() -> void:
	if not Engine.is_editor_hint() or _actor == null:
		return
	var stamp := _build_definition_stamp()
	if stamp == _last_definition_stamp:
		# Skip reapply work when authored values are unchanged.
		return
	_last_definition_stamp = stamp
	_actor.call("_apply_definition_to_children")


func _build_definition_stamp() -> String:
	if _actor == null:
		return ""
	var definition = _actor.get("definition")
	if definition == null:
		return ""
	var texture_path := ""
	var portrait_texture = definition.get("portrait_texture")
	if portrait_texture and not portrait_texture.resource_path.is_empty():
		texture_path = portrait_texture.resource_path
	var conversation_path := ""
	var conversation = definition.get("conversation")
	if conversation and not conversation.resource_path.is_empty():
		conversation_path = conversation.resource_path
	# Stable stamp over user-facing definition fields used by scene previews.
	return "%s|%s|%s|%s|%s|%s|%s" % [
		definition.get_instance_id(),
		str(definition.get("speaker_name")),
		str(definition.get("opening_text")),
		conversation_path,
		str(definition.get("height_meters")),
		str(definition.get("sprite_scale")),
		texture_path,
	]
