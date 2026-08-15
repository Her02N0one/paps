## Shows a choice when one persistent global flag equals the expected value.
class_name DialogueFlagCondition
extends DialogueCondition

@export var flag: StringName
@export var expected_value: Variant = true


func is_met(context: DialogueContext) -> bool:
	if context == null:
		return false
	var actual: bool = context.get_flag(flag, false)
	var expected: bool = expected_value
	return actual == expected
