## Data-driven death effect configuration used by ActorDeathEffectsComponent.
class_name ActorDeathEffectProfile
extends Resource

enum ParentMode {
	OWNER_PARENT,
	WORLD_EFFECT_ROOT,
	CURRENT_SCENE,
}

@export var id: StringName = &""
@export var effect_scene: PackedScene
@export var parent_mode: ParentMode = ParentMode.WORLD_EFFECT_ROOT
@export var spawn_offset_local := Vector3.ZERO
@export var inherit_owner_rotation := true
@export_range(0.0, 10.0, 0.01) var effect_lifetime_seconds := 2.0

@export_group("Owner Lifecycle")
@export var queue_free_owner := true
@export_range(0.0, 10.0, 0.01) var queue_free_owner_delay_seconds := 0.0
@export var hide_owner_visuals_on_trigger := true
