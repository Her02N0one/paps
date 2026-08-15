## Drag into any scene to leave a floating spatial annotation visible in the editor.
@tool
class_name DocNote
extends Node3D

enum Category { NOTE, TODO, BUG, REVIEW }

const _COLORS: Dictionary = {
	Category.NOTE:   Color(0.4, 0.8, 1.0),
	Category.TODO:   Color(1.0, 0.85, 0.2),
	Category.BUG:    Color(1.0, 0.3,  0.3),
	Category.REVIEW: Color(0.7, 0.4,  1.0),
}

@export_multiline var text: String = "":
	set(v): text = v; _refresh()

@export var category: Category = Category.NOTE:
	set(v): category = v; _refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	var label := get_node_or_null("_Label") as Label3D
	if label == null:
		label = Label3D.new()
		label.name = "_Label"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.005
		label.font_size = 36
		label.outline_size = 6
		label.outline_modulate = Color.BLACK
		add_child(label)
		if Engine.is_editor_hint() and is_inside_tree():
			label.owner = get_tree().edited_scene_root
	label.text = "[%s]\n%s" % [Category.keys()[category], text]
	label.modulate = _COLORS.get(category, Color.WHITE)
