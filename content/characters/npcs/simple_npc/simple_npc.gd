@tool
class_name SimpleNPC
extends StaticBody3D

@export var person_id: StringName
@export var definition: PersonDefinition:
	set(value):
		if definition == value: return
		if definition != null and definition.changed.is_connected(_on_definition_changed):
			definition.changed.disconnect(_on_definition_changed)
		definition = value
		if definition != null and not definition.changed.is_connected(_on_definition_changed):
			definition.changed.connect(_on_definition_changed)
		_apply_definition()

func _on_definition_changed() -> void:
	if Engine.is_editor_hint():
		_apply_definition()

@export_group("Schedule")
## The hour (0.0 to 24.0) when this NPC appears.
@export_range(0.0, 24.0, 0.5) var active_start_hour: float = 0.0
## The hour (0.0 to 24.0) when this NPC disappears (simulating travel/sleep).
@export_range(0.0, 24.0, 0.5) var active_end_hour: float = 24.0

var _game_state: GameState

@export var sprite: Sprite3D
@export var collision: CollisionShape3D
@export var health_component: ActorHealthComponent
@export var interactable: InteractablePerson

func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_definition()
		return
	
	_game_state = ServiceRegistry.game_state
	if _game_state != null and not person_id.is_empty():
		if not ServiceRegistry.npc_manager.is_person_enabled(person_id):
			queue_free()
			return
			
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.hour_tick.connect(_on_hour_tick)
	
	_apply_definition()
	_update_schedule_visibility()
	
	if health_component != null:
		health_component.defeated.connect(_on_defeated)

func _on_defeated(_source: Node) -> void:
	if _game_state != null and not person_id.is_empty():
		ServiceRegistry.npc_manager.set_person_enabled(person_id, false)
	queue_free()

func _on_hour_tick(_hour: int) -> void:
	_update_schedule_visibility()

func _update_schedule_visibility() -> void:
	if _game_state == null:
		return
	# If start == end, they are active 24/7.
	if is_equal_approx(active_start_hour, active_end_hour):
		visible = true
		process_mode = Node.PROCESS_MODE_INHERIT
		return
		
	var current_minutes: float = _game_state.current_time_minutes
	var current_hour: float = current_minutes / 60.0
	
	var is_active := false
	if active_start_hour <= active_end_hour:
		is_active = (current_hour >= active_start_hour) and (current_hour < active_end_hour)
	else:
		# Wraps around midnight
		is_active = (current_hour >= active_start_hour) or (current_hour < active_end_hour)
		
	visible = is_active
	process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED

func _apply_definition() -> void:
	if definition == null or not is_node_ready():
		return
	
	if sprite != null:
		sprite.texture = definition.body_texture
		sprite.scale = definition.sprite_scale
		sprite.modulate = definition.sprite_tint
		var tex_height := sprite.texture.get_height() if sprite.texture else 0
		if tex_height > 0 and definition.height_meters > 0.0:
			var scale_factor = definition.sprite_scale.y if definition.sprite_scale.y > 0 else 1.0
			sprite.pixel_size = definition.height_meters / (float(tex_height) * scale_factor)
			sprite.position.y = definition.height_meters * 0.5
	
	if collision != null and collision.shape is CapsuleShape3D:
		var capsule := collision.shape as CapsuleShape3D
		var target_radius := clampf(definition.height_meters * 0.16, 0.18, 0.45)
		capsule.radius = target_radius
		capsule.height = maxf(definition.height_meters - (target_radius * 2.0), target_radius * 0.5)
		collision.position.y = definition.height_meters * 0.5
		
	if health_component != null:
		health_component.apply_person_definition(definition)
		
	if interactable != null and not Engine.is_editor_hint():
		interactable.set_person_definition(definition)
