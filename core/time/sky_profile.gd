@tool
class_name SkyProfile extends Resource

@export_group("Moon Phases")
## An array of textures for the moon phases, mapped to the day.
@export var moon_phase_textures: Array[Texture2D] = []

@export_group("Gradients & Curves")
@export var sun_color: Gradient
@export var sun_energy_curve: Curve
@export var sky_top_color: Gradient
@export var sky_horizon_color: Gradient

func _init() -> void:
	if sun_color == null:
		sun_color = Gradient.new()
		sun_color.set_color(0, Color(0.05, 0.05, 0.15))
		sun_color.set_color(1, Color(0.05, 0.05, 0.15))
		sun_color.add_point(0.25, Color(1.0, 0.5, 0.2))
		sun_color.add_point(0.5, Color(1.0, 1.0, 1.0))
		sun_color.add_point(0.75, Color(1.0, 0.5, 0.2))
		
	if sky_top_color == null:
		sky_top_color = Gradient.new()
		sky_top_color.set_color(0, Color(0.0, 0.0, 0.02))
		sky_top_color.set_color(1, Color(0.0, 0.0, 0.02))
		sky_top_color.add_point(0.25, Color(0.3, 0.4, 0.6))
		sky_top_color.add_point(0.5, Color(0.2, 0.5, 0.8))
		sky_top_color.add_point(0.75, Color(0.2, 0.2, 0.4))

	if sky_horizon_color == null:
		sky_horizon_color = Gradient.new()
		sky_horizon_color.set_color(0, Color(0.02, 0.02, 0.05))
		sky_horizon_color.set_color(1, Color(0.02, 0.02, 0.05))
		sky_horizon_color.add_point(0.25, Color(0.8, 0.4, 0.2))
		sky_horizon_color.add_point(0.5, Color(0.5, 0.7, 0.9))
		sky_horizon_color.add_point(0.75, Color(0.7, 0.3, 0.5))
		
	if sun_energy_curve == null:
		sun_energy_curve = Curve.new()
		sun_energy_curve.add_point(Vector2(0.0, 0.0))
		sun_energy_curve.add_point(Vector2(0.2, 0.0))
		sun_energy_curve.add_point(Vector2(0.25, 0.5))
		sun_energy_curve.add_point(Vector2(0.5, 1.0))
		sun_energy_curve.add_point(Vector2(0.75, 0.5))
		sun_energy_curve.add_point(Vector2(0.8, 0.0))
		sun_energy_curve.add_point(Vector2(1.0, 0.0))
