@tool
class_name SimpleNPC
extends StaticBody3D

@export var person_id: StringName
@export var definition: PersonDefinition:
	set(value):
		if definition == value: return
		definition = value
		_apply_definition()

@export_group("Schedule")
## The hour (0.0 to 24.0) when this NPC appears.
@export_range(0.0, 24.0, 0.5) var active_start_hour: float = 0.0
## The hour (0.0 to 24.0) when this NPC disappears (simulating travel/sleep).
@export_range(0.0, 24.0, 0.5) var active_end_hour: float = 24.0

var _game_state: GameState

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var health_component: ActorHealthComponent = $ActorHealthComponent
@onready var interactable: InteractablePerson = $InteractablePerson

func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_definition()
		return
	
	_game_state = ServiceRegistry.game_state
	if _game_state != null and not person_id.is_empty():
		if not _game_state.is_person_enabled(person_id):
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
		_game_state.set_person_enabled(person_id, false)
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
