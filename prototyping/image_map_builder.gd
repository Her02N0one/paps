class_name ImageMapBuilder
extends Node3D


const default_tile_size = 10

@export_file("*.png") var elevation_layer: String
@export_file("*.png") var features_layer: String
@export var grid_map: GridMap

@export var wasteland: ProtoTileData = ProtoTileData.new()
@export var features: Dictionary[Color, ProtoTileData]

var _filler_item_id: int = 0

@export_group("Elevation Mapping")
@export var base_elevation_step: float = 0.5 ## Height in meters of a single walkable band
@export var cliff_threshold_band: int = 16 ## Grayscale band (0-31) where terrain turns into cliffs
@export var cliff_band_multiplier: int = 4 ## How many base steps a cliff band jumps



func _ready() -> void:
	if grid_map == null:
		push_error("ImageMapBuilder requires a GridMap node.")
		return
		
	# Dynamically update the GridMap cell height to match our base step
	grid_map.cell_size.y = base_elevation_step
	
	_build_mesh_library()
	_build_map()



func _build_mesh_library() -> void:
	var lib = MeshLibrary.new()
	
	var base_mat = load("res://content/zones/maps/grid_floor.tres") as ShaderMaterial
	
	# Item 0: Wasteland (Grey)
	var mat_waste = base_mat.duplicate()
	mat_waste.set_shader_parameter("base_color", Color(0.4, 0.4, 0.4))
	mat_waste.set_shader_parameter("grid_color", Color(0.3, 0.3, 0.3))
	mat_waste.set_shader_parameter("grid_size", 1)
	var mesh_waste = BoxMesh.new()
	mesh_waste.size = Vector3(default_tile_size, base_elevation_step, default_tile_size)
	mesh_waste.material = mat_waste
	lib.create_item(0)
	lib.set_item_mesh(0, mesh_waste)
	var shape_waste = BoxShape3D.new()
	shape_waste.size = Vector3(default_tile_size, base_elevation_step, default_tile_size)
	lib.set_item_shapes(0, [shape_waste, Transform3D.IDENTITY])
	
	var count = 1

	for feature in features:
		var feature_data = features[feature]
		var mat = base_mat.duplicate()
		mat.set_shader_parameter("base_color", feature_data.base_color)
		mat.set_shader_parameter("grid_color", feature_data.base_color)
		mat.set_shader_parameter("grid_size", feature_data.grid_size)
		var mesh = BoxMesh.new()
		mesh.size = Vector3(default_tile_size, base_elevation_step * feature_data.elevation_multiplier, default_tile_size)
		mesh.material = mat
		lib.create_item(count)
		lib.set_item_mesh(count, mesh)
		var shape = BoxShape3D.new()
		shape.size = Vector3(default_tile_size, base_elevation_step * feature_data.elevation_multiplier, default_tile_size)
		lib.set_item_shapes(count, [shape, Transform3D.IDENTITY])
		count += 1
	
	# Last Item: Filler Wasteland (No Collision)
	lib.create_item(count)
	lib.set_item_mesh(count, mesh_waste)
	# Purposely NO shapes for the filler item so Jolt Physics isn't overwhelmed by underground blocks
	_filler_item_id = count

	grid_map.mesh_library = lib


func _get_y_level(img_elev: Image, x: int, z: int) -> int:
	var elev_color = img_elev.get_pixel(x, z)
	var v = int(elev_color.r * 255.0)
	
	# Round to nearest multiple of 8 to create bands
	var band = v / 8
	
	if band <= cliff_threshold_band:
		return band
	else:
		return cliff_threshold_band + ((band - cliff_threshold_band) * cliff_band_multiplier)

func _build_map() -> void:
	if elevation_layer.is_empty() or features_layer.is_empty():
		push_warning("Map builder missing PNG paths. Skipping generation.")
		return
		
	var tex_elev = load(elevation_layer) as Texture2D
	var tex_feat = load(features_layer) as Texture2D
	
	if tex_elev == null or tex_feat == null:
		push_error("Failed to load map PNGs as Textures.")
		return
		
	var img_elev = tex_elev.get_image()
	var img_feat = tex_feat.get_image()
	
	if img_elev == null or img_feat == null:
		push_error("Failed to load map PNGs.")
		return
		
	if img_elev.get_size() != img_feat.get_size():
		push_error("Elevation and Features layers must be the exact same resolution.")
		return
		
	var width = img_elev.get_width()
	var height = img_elev.get_height()
	
	for x in range(width):
		for z in range(height):
			var y_level = _get_y_level(img_elev, x, z)
			
			var feat_color = img_feat.get_pixel(x, z)
			var item_id = 0 # Default to Wasteland

			if feat_color.a > 0.5:
				var idx = 1
				for feature in features:
					if _color_match(feat_color, feature):
						item_id = idx
						break
					idx += 1

			# Place the surface block (with collision)
			grid_map.set_cell_item(Vector3i(x, y_level, z), item_id)

			# Find the lowest neighbor height so we only fill the visible cliff faces
			var min_neighbor_y = y_level
			if x > 0: min_neighbor_y = min(min_neighbor_y, _get_y_level(img_elev, x-1, z))
			if x < width - 1: min_neighbor_y = min(min_neighbor_y, _get_y_level(img_elev, x+1, z))
			if z > 0: min_neighbor_y = min(min_neighbor_y, _get_y_level(img_elev, x, z-1))
			if z < height - 1: min_neighbor_y = min(min_neighbor_y, _get_y_level(img_elev, x, z+1))

			# Fill downwards only as far as the lowest neighbor, using NON-COLLIDING filler blocks
			for fill_y in range(min_neighbor_y, y_level):
				grid_map.set_cell_item(Vector3i(x, fill_y, z), _filler_item_id)

func _color_match(c1: Color, c2: Color, tolerance: float = 0.1) -> bool:
	return abs(c1.r - c2.r) < tolerance and abs(c1.g - c2.g) < tolerance and abs(c1.b - c2.b) < tolerance
