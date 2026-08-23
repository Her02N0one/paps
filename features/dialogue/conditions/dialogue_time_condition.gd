@tool
class_name DialogueTimeCondition
extends DialogueCondition

@export var start_hour: float = 0.0
@export var end_hour: float = 24.0
@export var inverse: bool = false

func is_met(_game_state: GameState, _speaker: Node) -> bool:
	if _game_state == null:
		return false
		
	var current_minutes: float = _game_state.current_time_minutes
	var current_hour: float = current_minutes / 60.0
	
	var in_range := false
	if start_hour <= end_hour:
		in_range = (current_hour >= start_hour) and (current_hour <= end_hour)
	else:
		# Wrap around midnight (e.g. 22.0 to 6.0)
		in_range = (current_hour >= start_hour) or (current_hour <= end_hour)
		
	return not in_range if inverse else in_range
