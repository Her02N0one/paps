@tool
class_name DayNightCycle
extends Node

@export var enabled: bool = true
@export var profile: SkyProfile:
	set(value):
		profile = value
		if Engine.is_editor_hint() and is_node_ready():
			_update_lighting(initial_time_minutes)



@export_group("Lighting Settings")
@export var sun_light: DirectionalLight3D
@export var moon_light: DirectionalLight3D
@export var moon_sprite: Sprite3D
@export var world_environment: WorldEnvironment
@export var initial_time_minutes: float = 480.0: # 8:00 AM default in editor
	set(value):
		initial_time_minutes = value
		if Engine.is_editor_hint() and is_node_ready():
			_update_lighting(initial_time_minutes)


func _ready() -> void:
	if not enabled:
		return
	if not Engine.is_editor_hint():
		assert(profile != null, "DayNightCycle requires a SkyProfile reference.")
		assert(sun_light != null, "DayNightCycle requires a SunLight reference.")
		assert(moon_light != null, "DayNightCycle requires a MoonLight reference.")
		assert(moon_sprite != null, "DayNightCycle requires a MoonSprite reference.")
		assert(world_environment != null, "DayNightCycle requires a WorldEnvironment reference.")
		assert(world_environment.environment != null, "DayNightCycle requires an Environment on the WorldEnvironment.")
		assert(world_environment.environment.sky != null, "DayNightCycle requires a Sky on the Environment.")
		assert(world_environment.environment.sky.sky_material is ProceduralSkyMaterial, "DayNightCycle requires a ProceduralSkyMaterial on the Sky.")
		
		TimeManager.time_changed.connect(_on_time_changed)
		
		var gs = ServiceRegistry.game_state
		assert(gs != null, "DayNightCycle requires a GameState.")
		_update_lighting(gs.current_time_minutes)
		_update_moon_phase(gs.current_day)
	else:
		_update_lighting(initial_time_minutes)

func _process(_delta: float) -> void:
	if not enabled:
		return
	if Engine.is_editor_hint():
		return # Editor previews are now driven efficiently via property setters instead of every frame
	else:
		# Lock celestial lights to the camera position so their children (like MoonSprite) 
		# are rendered at 'infinity' without any parallax shifting when the player walks.
		var camera = get_viewport().get_camera_3d()
		if camera != null:
			sun_light.global_position = camera.global_position
			moon_light.global_position = camera.global_position

func _on_time_changed(day: int, minutes: float) -> void:
	_update_lighting(minutes)
	_update_moon_phase(day)

func _update_moon_phase(day: int) -> void:
	if profile != null and profile.moon_phase_textures.size() > 0:
		var tex = profile.moon_phase_textures[day % profile.moon_phase_textures.size()]
		assert(tex != null, "Moon phase texture is null for day " + str(day))
		moon_sprite.texture = tex

func _update_lighting(minutes: float) -> void:
	if profile == null:
		return
	var time_ratio := clampf(minutes / 1440.0, 0.0, 1.0)
	var sun_angle_degrees = (time_ratio * 360.0) - 90.0
	
	# Setting all three euler axes prevents 'wonky' gimbal lock/interpolation issues
	if is_instance_valid(sun_light):
		sun_light.rotation_degrees = Vector3(-sun_angle_degrees, 45.0, 0.0)
		sun_light.light_color = profile.sun_color.sample(time_ratio)
		sun_light.light_energy = profile.sun_energy_curve.sample(time_ratio)

	# Moon opposes the sun. When sun is -90 (midnight), moon is 90 (noon relative).
	# We want the moon to shine down at night.
	if is_instance_valid(moon_light):
		moon_light.rotation_degrees = Vector3(-sun_angle_degrees + 180.0, 45.0, 0.0)
		# Fade moon out during the day
		if time_ratio > 0.25 and time_ratio < 0.75:
			moon_light.light_energy = lerpf(moon_light.light_energy, 0.0, 0.1)
		else:
			moon_light.light_energy = lerpf(moon_light.light_energy, 0.5, 0.1)

	if is_instance_valid(world_environment):
		var sky_mat := world_environment.environment.sky.sky_material as ProceduralSkyMaterial
		if profile.sky_top_color:
			sky_mat.sky_top_color = profile.sky_top_color.sample(time_ratio)
		if profile.sky_horizon_color:
			sky_mat.sky_horizon_color = profile.sky_horizon_color.sample(time_ratio)
