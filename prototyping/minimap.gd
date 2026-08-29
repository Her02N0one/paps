extends CanvasLayer

@export var map_texture: Texture2D
@export var default_map_path: String = "res://prototyping/maps/features.png"

@export var mask: Control
@export var texture_rect: TextureRect
@export var player_dot: ColorRect
@export var label: Label

var player: Node3D
var zoom_levels = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
var current_zoom_index = 2 # Default to 1.0x

func _ready() -> void:
	if map_texture != null:
		texture_rect.texture = map_texture
	else:
		var tex = load(default_map_path) as Texture2D
		if tex != null:
			texture_rect.texture = tex
			
	_update_zoom_label()

func _process(_delta: float) -> void:
	if player == null and ServiceRegistry.world != null:
		player = ServiceRegistry.world.get("player")
	if player != null and texture_rect.texture != null:
		# Player position in pixels (1 pixel = 10 meters)
		var player_pixel_pos = Vector2(player.global_position.x / 10.0, player.global_position.z / 10.0)
		
		var zoom = zoom_levels[current_zoom_index]
		texture_rect.scale = Vector2(zoom, zoom)
		
		var tex_size = texture_rect.texture.get_size()
		var scaled_size = tex_size * zoom
		var mask_size = mask.size
		
		var map_pos = Vector2()
		
		for axis in [Vector2.AXIS_X, Vector2.AXIS_Y]:
			if scaled_size[axis] <= mask_size[axis]:
				# Map is smaller than mask, center the map perfectly in the mask
				map_pos[axis] = (mask_size[axis] - scaled_size[axis]) / 2.0
			else:
				# Map is larger than mask, apply clamping to prevent seeing the void
				var ideal_pos = (mask_size[axis] / 2.0) - (player_pixel_pos[axis] * zoom)
				var min_pos = mask_size[axis] - scaled_size[axis]
				var max_pos = 0.0
				map_pos[axis] = clampf(ideal_pos, min_pos, max_pos)
		
		texture_rect.position = map_pos
		
		# Place player dot relative to the map (within the mask space)
		player_dot.position = map_pos + (player_pixel_pos * zoom) - (player_dot.size / 2.0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			current_zoom_index = (current_zoom_index + 1) % zoom_levels.size()
			_update_zoom_label()

func _update_zoom_label() -> void:
	if label != null:
		var z = zoom_levels[current_zoom_index]
		if z < 1.0:
			label.text = "Minimap [M]\nZoom: 1/%dx" % int(1.0 / z)
		else:
			label.text = "Minimap [M]\nZoom: %dx" % int(z)
