@tool
extends GamePanel
class_name LoadMenuPanel

@onready var save_list: VBoxContainer = %SaveList
@onready var close_button: Button = %CloseButton

var save_manager

func _ready() -> void:
	if close_button:
		close_button.pressed.connect(close_panel)
		
	visibility_changed.connect(func():
		if visible:
			_refresh_list()
			if save_list and save_list.get_child_count() > 0:
				var first_btn = save_list.get_child(0) as Button
				if first_btn:
					first_btn.grab_focus()
			elif close_button:
				close_button.grab_focus()
	)
		
	# Delay binding to let main loop register autoloads
	call_deferred("_bind_save_manager")


func _bind_save_manager() -> void:
	# Assume root context has bound SaveManager and we can reach it
	var root_context = get_node("/root/RootContext") as RootContext
	save_manager = root_context.get_save_manager()


func open_panel() -> void:
	show()


func _refresh_list() -> void:
	if not save_manager or not save_list:
		return
		
	for child in save_list.get_children():
		child.queue_free()
		
	var saves = save_manager.get_all_saves()
	for metadata in saves:
		var row_hbox = HBoxContainer.new()
		
		var btn = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 40)
		
		var hbox = HBoxContainer.new()
		hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 10
		hbox.offset_right = -10
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(hbox)
		
		var name_lbl = Label.new()
		var time_lbl = Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		time_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		var s_name = str(metadata.get("save_name", "UNKNOWN SAVE"))
		var s_time = str(metadata.get("saved_at_utc", ""))
		var filename = str(metadata.get("filename", ""))
		
		if s_time.length() >= 16:
			s_time = s_time.replace("T", " ").substr(0, 16)
			
		var display_name = s_name.to_upper()
		if filename.ends_with(".backup"):
			display_name += " (BACKUP)"
			
		name_lbl.text = display_name
		time_lbl.text = s_time
		
		hbox.add_child(name_lbl)
		hbox.add_child(time_lbl)
		
		btn.pressed.connect(_on_save_selected.bind(filename))
		
		var del_btn = Button.new()
		del_btn.text = "X"
		del_btn.custom_minimum_size = Vector2(40, 40)
		del_btn.pressed.connect(_on_delete_pressed.bind(filename))
		
		row_hbox.add_child(btn)
		row_hbox.add_child(del_btn)
		save_list.add_child(row_hbox)
		
	if saves.is_empty():
		var lbl = Label.new()
		lbl.text = "No saves found."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		save_list.add_child(lbl)


func _on_save_selected(filename: String) -> void:
	if not save_manager:
		return
	
	if save_manager.load_game(filename):
		close_panel()
		# Find GameManager to continue
		var root_context = get_node("/root/RootContext") as RootContext
		root_context.get_game_manager().continue_game()


func _on_delete_pressed(filename: String) -> void:
	var sm := save_manager as SaveManager
	if sm:
		sm.delete_save(filename)
		_refresh_list()
