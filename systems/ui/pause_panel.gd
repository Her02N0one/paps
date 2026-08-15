@tool
## Pause menu surface that forwards button presses as semantic signals.
class_name PausePanelSurface
extends GamePanel

signal resume_pressed
signal quick_save_pressed
signal load_game_pressed
signal quit_to_menu_pressed
signal quit_game_pressed
signal manual_save_pressed

var status_label: Label

func _init() -> void:
	modal_id = &"pause"
	pauses_game = true

func _ready() -> void:
	var vbox = get_node_or_null("PauseMargin/PauseVBox")
	if vbox:
		# Convert existing buttons to caps
		for child in vbox.get_children():
			if child is Button:
				child.text = child.text.to_upper()
			elif child is Label:
				child.text = child.text.to_upper()
				
		var manual_save_btn = Button.new()
		manual_save_btn.text = "SAVE GAME"
		manual_save_btn.pressed.connect(_on_manual_save_pressed)
		
		# insert before Load Game if possible
		var load_btn_idx = 0
		for i in range(vbox.get_child_count()):
			if vbox.get_child(i).name == "PauseLoadGame":
				load_btn_idx = i
				break
		if load_btn_idx > 0:
			vbox.add_child(manual_save_btn)
			vbox.move_child(manual_save_btn, load_btn_idx)
		else:
			vbox.add_child(manual_save_btn)
			
		status_label = Label.new()
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.modulate.a = 0
		vbox.add_child(status_label)

func show_status(text: String) -> void:
	if not status_label:
		return
	status_label.text = text
	status_label.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_property(status_label, "modulate:a", 0.0, 2.0).set_delay(1.0)

func _on_manual_save_pressed() -> void:
	manual_save_pressed.emit()


func _on_resume_pressed() -> void:
	resume_pressed.emit()


func _on_quick_save_pressed() -> void:
	quick_save_pressed.emit()


func _on_load_game_pressed() -> void:
	load_game_pressed.emit()


func _on_quit_to_menu_pressed() -> void:
	quit_to_menu_pressed.emit()


func _on_quit_game_pressed() -> void:
	quit_game_pressed.emit()
