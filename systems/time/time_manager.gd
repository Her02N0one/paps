extends Node

## Emitted every frame the game time changes.
signal time_changed(day: int, minutes: float)
## Emitted when an in-game hour passes (0-23).
signal hour_tick(hour: int)
## Emitted when an in-game day rolls over.
signal day_tick(day: int)

## Time scale multiplier relative to real-time.
## 1 hour (60 in-game minutes) = 15 real minutes.
## 60 / 15 = 4.0. So in-game time moves 4x faster than real-time.
@export var time_scale: float = 4.0

var _game_state: GameState
var _last_hour: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game_state = get_tree().get_first_node_in_group("game_state") as GameState
	if _game_state:
		_last_hour = int(_game_state.current_time_minutes) / 60

func _process(delta: float) -> void:
	if _game_state == null:
		_game_state = get_tree().get_first_node_in_group("game_state") as GameState
		return
		
	if get_tree().paused:
		return

	# delta is real seconds. 
	# delta / 60.0 is real minutes passed this frame.
	# (delta / 60.0) * time_scale is in-game minutes passed this frame.
	var in_game_minutes_passed := (delta / 60.0) * time_scale
	advance_time(in_game_minutes_passed)

## Skips time forward by a specific number of in-game minutes (e.g. for campfires).
func skip_time(minutes_to_add: float) -> void:
	if _game_state == null:
		return
	advance_time(minutes_to_add)

func advance_time(minutes: float) -> void:
	_game_state.current_time_minutes += minutes
	
	while _game_state.current_time_minutes >= 1440.0:
		_game_state.current_time_minutes -= 1440.0
		_game_state.current_day += 1
		day_tick.emit(_game_state.current_day)
		
	time_changed.emit(_game_state.current_day, _game_state.current_time_minutes)
	
	var current_hour := int(_game_state.current_time_minutes) / 60
	if current_hour != _last_hour:
		_last_hour = current_hour
		hour_tick.emit(current_hour)
