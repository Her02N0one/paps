@tool
class_name SimpleNPC
extends StaticBody3D

@export var person_id: StringName
@export var definition: PersonDefinition:
	set(value):
		if definition == value: return
		definition = value
		_apply_definition()

var _game_state: GameState

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var health_component: ActorHealthComponent = $ActorHealthComponent
@onready var interactable: InteractablePerson = $InteractablePerson

func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_definition()
		return
	
	_game_state = get_tree().get_first_node_in_group("game_state") as GameState
	if _game_state != null and not person_id.is_empty():
		if not _game_state.is_person_enabled(person_id):
			queue_free()
			return
			
	_apply_definition()
	
	if health_component != null:
		health_component.defeated.connect(_on_defeated)

func _on_defeated(_source: Node) -> void:
	if _game_state != null and not person_id.is_empty():
		_game_state.set_person_enabled(person_id, false)
	queue_free()

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
