@tool
class_name DayNightCycle
extends Node

@export_group("Lighting Settings")
@export var sun_light: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var initial_time_minutes: float = 480.0 # 8:00 AM default in editor

@export_group("Gradients & Curves")
## Color of the sun from 00:00 to 24:00
@export var sun_color: Gradient
## Intensity of the sun from 00:00 to 24:00 (Y = energy multiplier)
@export var sun_energy_curve: Curve
## Color of the sky/ambient light from 00:00 to 24:00
@export var sky_color: Gradient

func _ready() -> void:
	_ensure_defaults()
	if not Engine.is_editor_hint():
		var tm = get_node_or_null("/root/TimeManager")
		if tm:
			tm.time_changed.connect(_on_time_changed)
			# Force initial update from game state if available
			var gs = get_tree().get_first_node_in_group("game_state") as GameState
			if gs:
				_update_lighting(gs.current_time_minutes)
			else:
				_update_lighting(initial_time_minutes)
		else:
			_update_lighting(initial_time_minutes)
	else:
		_update_lighting(initial_time_minutes)

func _ensure_defaults() -> void:
	if sun_color == null:
		sun_color = Gradient.new()
		sun_color.set_color(0, Color(0.05, 0.05, 0.15))
		sun_color.set_color(1, Color(0.05, 0.05, 0.15))
		sun_color.add_point(0.25, Color(1.0, 0.5, 0.2))
		sun_color.add_point(0.5, Color(1.0, 1.0, 1.0))
		sun_color.add_point(0.75, Color(1.0, 0.5, 0.2))
		
	if sky_color == null:
		sky_color = Gradient.new()
		sky_color.set_color(0, Color(0.01, 0.01, 0.05))
		sky_color.set_color(1, Color(0.01, 0.01, 0.05))
		sky_color.add_point(0.25, Color(0.6, 0.3, 0.1))
		sky_color.add_point(0.5, Color(0.4, 0.6, 1.0))
		sky_color.add_point(0.75, Color(0.6, 0.3, 0.1))
		
	if sun_energy_curve == null:
		sun_energy_curve = Curve.new()
		sun_energy_curve.add_point(Vector2(0.0, 0.0))
		sun_energy_curve.add_point(Vector2(0.2, 0.0))
		sun_energy_curve.add_point(Vector2(0.25, 0.5))
		sun_energy_curve.add_point(Vector2(0.5, 1.0))
		sun_energy_curve.add_point(Vector2(0.75, 0.5))
		sun_energy_curve.add_point(Vector2(0.8, 0.0))
		sun_energy_curve.add_point(Vector2(1.0, 0.0))

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_update_lighting(initial_time_minutes)

func _on_time_changed(_day: int, minutes: float) -> void:
	_update_lighting(minutes)

func _update_lighting(minutes: float) -> void:
	if not is_instance_valid(sun_light):
		return
		
	# Normalize time to 0.0 - 1.0 (00:00 to 24:00)
	var time_ratio := clampf(minutes / 1440.0, 0.0, 1.0)
	
	# Rotation: Sun rises at 0.25 (6:00), peaks at 0.5 (12:00), sets at 0.75 (18:00)
	# 360 degrees over 24 hours. Offset by 90 degrees so 00:00 points up (midnight).
	var angle_degrees = (time_ratio * 360.0) - 90.0
	sun_light.rotation_degrees.x = -angle_degrees
	
	if sun_color != null:
		sun_light.light_color = sun_color.sample(time_ratio)
		
	if sun_energy_curve != null:
		sun_light.light_energy = sun_energy_curve.sample(time_ratio)
		
	if is_instance_valid(world_environment) and sky_color != null:
		var env = world_environment.environment
		if env != null:
			env.ambient_light_color = sky_color.sample(time_ratio)
			# If using procedural sky, you can also set sky_material properties here.
