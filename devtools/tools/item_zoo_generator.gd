## Add to any scene to auto-lay out every ItemDefinition in res://content/items/presets/ as a
## display tile showing the real in-game item mesh, color-coded by item type.
@tool
class_name ItemZooGenerator
extends Node3D

const _ITEMS_DIR    := "res://content/items/presets/"
const _PICKUP_SCENE := preload("res://content/items/pickup_item.tscn")
const _COLS         := 4
const _COL_SPACING  := 4.0
const _ROW_SPACING  := 5.0

# Platform tints: green=consumable, blue=key/non-droppable, amber=scrappable, gray=default
const _COLOR_CONSUMABLE  := Color(0.22, 0.38, 0.22)
const _COLOR_KEY_ITEM    := Color(0.22, 0.26, 0.45)
const _COLOR_SCRAPPABLE  := Color(0.40, 0.30, 0.14)
const _COLOR_DEFAULT     := Color(0.26, 0.26, 0.30)

@export_tool_button("Generate Item Zoo") var _gen_btn := generate_zoo


func _ready() -> void:
	if not Engine.is_editor_hint():
		generate_zoo()


func generate_zoo() -> void:
	if Engine.is_editor_hint():
		for child in get_children():
			child.free()
	elif not get_children().is_empty():
		return

	_place_header()

	var items := _load_all_items()
	var col_offset := (_COLS - 1) * 0.5 * _COL_SPACING
	for i in items.size():
		var col := i % _COLS
		var row := i / _COLS
		var pos := Vector3(
			col * _COL_SPACING - col_offset,
			0.0,
			(row + 1) * _ROW_SPACING
		)
		_place_tile(items[i], pos, i)

	print("[ItemZoo] Placed %d items." % items.size())


func _load_all_items() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	var dir := DirAccess.open(_ITEMS_DIR)
	if dir == null:
		push_error("ItemZooGenerator: cannot open %s" % _ITEMS_DIR)
		return result
	dir.list_dir_begin()
	var file := dir.get_next()
	while not file.is_empty():
		if not dir.current_is_dir() and file.ends_with(".tres"):
			var item := load(_ITEMS_DIR + file) as ItemDefinition
			if item:
				result.append(item)
		file = dir.get_next()
	dir.list_dir_end()
	return result


func _place_header() -> void:
	var title := Label3D.new()
	title.text = "ITEM ZOO"
	title.position = Vector3(0.0, 3.0, 0.0)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.pixel_size = 0.006
	title.font_size = 72
	title.modulate = Color(1.0, 0.92, 0.4)
	title.outline_size = 10
	title.outline_modulate = Color(0.05, 0.05, 0.05)
	_add(title)

	var col_offset := (_COLS - 1) * 0.5 * _COL_SPACING
	var post_x := -col_offset - 2.5
	_scale_post(Vector3(post_x, 0.0, _ROW_SPACING))


func _scale_post(base_pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 1.0, 0.08)
	mi.mesh = mesh
	mi.position = base_pos + Vector3(0.0, 0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.9)
	mi.material_override = mat
	_add(mi)

	var lbl := Label3D.new()
	lbl.text = "1 m"
	lbl.position = base_pos + Vector3(0.35, 0.5, 0.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.pixel_size = 0.004
	lbl.font_size = 24
	lbl.modulate = Color(0.85, 0.85, 0.85)
	lbl.outline_size = 4
	lbl.outline_modulate = Color.BLACK
	_add(lbl)


func _place_tile(item: ItemDefinition, pos: Vector3, index: int) -> void:
	var base_color := _platform_color(item)

	var mi := MeshInstance3D.new()
	mi.position = pos + Vector3(0.0, -0.06, 0.0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.4, 0.12, 3.2)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color
	mi.material_override = mat
	_add(mi)

	var pickup: PickupItem = _PICKUP_SCENE.instantiate()
	pickup.instance = ItemInstance.new(item, 1)
	pickup.dynamic_id = "zoo_%d" % index
	pickup.position = pos + Vector3(0.0, 0.12, 0.6)
	_add(pickup)

	if item.icon != null:
		var sprite := Sprite3D.new()
		sprite.texture = item.icon
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.004
		sprite.position = pos + Vector3(0.0, 1.6, 0.6)
		sprite.modulate = Color.WHITE
		_add(sprite)

	_label(pos + Vector3(0.0, 2.2, 0.0), item.display_name, 44, Color(1.0, 0.95, 0.45))

	if not item.description.is_empty():
		_label(pos + Vector3(0.0, 1.75, 0.0), item.description, 22, Color(0.85, 0.85, 0.85))

	_label(pos + Vector3(0.0, 1.4, 0.0), _stats(item), 20, Color(0.5, 0.85, 1.0))
	_label(pos + Vector3(0.0, 1.05, 0.0), "id: &\"%s\"" % item.id, 18, Color(0.5, 0.65, 0.5))


func _platform_color(item: ItemDefinition) -> Color:
	if item.consumed_on_use: return _COLOR_CONSUMABLE
	if not item.droppable:   return _COLOR_KEY_ITEM
	if item.scrap_yield > 0: return _COLOR_SCRAPPABLE
	return _COLOR_DEFAULT


func _stats(item: ItemDefinition) -> String:
	var parts: PackedStringArray = []
	parts.append("stack: %d" % item.max_stack if item.stackable else "not stackable")
	if item.scrap_yield > 0:
		parts.append("scrap \u00d7%d" % item.scrap_yield)
	if item.consumed_on_use:
		parts.append("consumable")
	if not item.droppable:
		parts.append("key item")
	return "  |  ".join(parts)


func _label(pos: Vector3, text: String, size: int, color: Color) -> void:
	var lbl := Label3D.new()
	lbl.text        = text
	lbl.position    = pos
	lbl.billboard   = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.pixel_size  = 0.004
	lbl.font_size   = size
	lbl.modulate    = color
	lbl.outline_size = 6
	lbl.outline_modulate = Color.BLACK
	_add(lbl)


func _add(node: Node) -> void:
	add_child(node)
	if Engine.is_editor_hint() and is_inside_tree():
		node.owner = get_tree().edited_scene_root
