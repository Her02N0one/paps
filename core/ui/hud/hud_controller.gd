class_name HUDController
extends Control

@export var interact_hint: Label
@export var crosshair: Label

var _player: Player
var _focused_interactable: Interactable

func _ready() -> void:
	if interact_hint:
		interact_hint.visible = false
	if crosshair:
		crosshair.visible = true

func set_runtime_player(player: Player) -> void:
	if _player and _player != player and _player.interactable_changed.is_connected(_on_interactable_changed):
		_player.interactable_changed.disconnect(_on_interactable_changed)
	_player = player
	if _player and not _player.interactable_changed.is_connected(_on_interactable_changed):
		_player.interactable_changed.connect(_on_interactable_changed)
	_refresh_interact_hint()

func _on_interactable_changed(interactable: Variant) -> void:
	var new_focused := interactable as Interactable if is_instance_valid(interactable) and interactable is Interactable else null
	
	if interact_hint:
		# Only show interact hint if no modal is open. We can check the ModalManager via ServiceRegistry or a global group.
		# For now, we assume if mouse is captured, we can show hints.
		interact_hint.visible = new_focused != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		if new_focused:
			interact_hint.text = "[E]  " + new_focused.interact_label
			
	if is_instance_valid(_focused_interactable) and _focused_interactable.player_interaction_requested.is_connected(_on_interaction_requested):
		_focused_interactable.player_interaction_requested.disconnect(_on_interaction_requested)
		
	_focused_interactable = new_focused
	
	if _focused_interactable:
		_focused_interactable.player_interaction_requested.connect(_on_interaction_requested)

func _refresh_interact_hint() -> void:
	if _player:
		_on_interactable_changed(_player.get_current_interactable())

func _on_interaction_requested(request: PlayerInteractionRequest) -> void:
	# Hide the hint when interacting
	if interact_hint:
		interact_hint.visible = false
	# Broadcast the interaction request globally
	var bus = get_node_or_null("/root/MessageBus")
	if bus and bus.has_user_signal("interaction_requested"):
		bus.emit_signal("interaction_requested", request)
