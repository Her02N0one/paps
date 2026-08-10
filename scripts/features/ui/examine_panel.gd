@tool
## Simple modal surface for read-only examine text content.
class_name ExaminePanel
extends GamePanel

@onready var _title: Label = $VBox/Title
@onready var _content: Label = $VBox/Content


func show_content(title: String, content: String) -> void:
	# Called by GameUIController after an examine interaction request.
	_title.text = title
	_content.text = content
	visible = true
	opened.emit()


func _on_close_pressed() -> void:
	close_panel()
