## Extension point for gameplay changes caused by entering a node or choosing a response.
## Subclasses override apply() and should keep presentation concerns out of the effect.
class_name DialogueEffect
extends Resource


## Applies this consequence to the active interaction and game state.
func apply(_context: DialogueContext) -> void:
	pass
