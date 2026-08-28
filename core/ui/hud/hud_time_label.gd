extends Label

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_bind_to_time")

func _bind_to_time() -> void:
	var tm = get_node("/root/TimeManager")
	if not tm.time_changed.is_connected(_on_time_changed):
		tm.time_changed.connect(_on_time_changed)
		
	var gs = ServiceRegistry.game_state
	assert(gs != null, "HUDTimeLabel requires a GameState.")
	_on_time_changed(gs.current_day, gs.current_time_minutes)

func _on_time_changed(day: int, minutes: float) -> void:
	@warning_ignore("integer_division")
	var hours := int(minutes) / 60
	var mins := int(minutes) % 60
	text = "DAY %d, %02d:%02d" % [day, hours, mins]
