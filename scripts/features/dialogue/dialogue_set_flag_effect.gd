## Writes a persistent global flag when its node is entered or choice is selected.
class_name DialogueSetFlagEffect
extends DialogueEffect

@export var flag: StringName
@export var value: Variant = true


func apply(context: DialogueContext) -> void:
	if context:
		context.set_flag(flag, value)