## Extension point for hiding or showing a DialogueChoice.
## Subclasses override is_met() and expose any authoring inputs with @export.
class_name DialogueCondition
extends Resource


## Evaluates this requirement against the active interaction and game state.
func is_met(_context: DialogueContext) -> bool:
	return true
