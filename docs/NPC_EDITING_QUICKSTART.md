# NPC Editing Quickstart

This is the shortest path to making NPC changes safely.

## 1) Mental model (what actually controls behavior)

Each NPC is composed from 4 things:

1. Scene prefab (what nodes/components exist)
   - `scenes/world/entities/person.tscn` (minimal base)
   - `scenes/world/entities/person_civilian.tscn` (talk + movement)
   - `scenes/world/entities/person_hostile.tscn` (movement + health + combat)
2. Actor host script
   - `scripts/features/world/person_actor.gd`
   - Reads optional child components by exact node name.
3. Definition resource (tuning/profile)
   - `scripts/features/world/person_definition.gd`
   - Example: `resources/people/jerry_person_definition.tres`
4. Level placement (which prefab this NPC instance uses)
   - Example: `scenes/levels/playground.tscn`

If an NPC seems "broken", first check which prefab it instances in the level scene.

## 2) Fast edit map

### Change dialogue text/name/conversation
Edit the NPC definition resource:
- `speaker_name`
- `opening_text`
- `conversation`

Example file:
- `resources/people/jerry_person_definition.tres`

### Change movement speed/combat values
Edit the same definition resource:
- `move_speed_meters_per_sec`
- `max_health`
- `base_damage`
- `attack_range_meters`
- `attack_cooldown_seconds`
- `combat_engage_distance_meters`
- `combat_disengage_distance_meters`

### Change what capabilities an NPC has
Edit the prefab scene nodes:
- Add/remove `InteractablePerson`
- Add/remove `ActorMovementAIComponent`
- Add/remove `ActorHealthComponent`
- Add/remove `ActorCombatComponent`
- Add/remove `ActorCombatAIComponent`

Important: those node names are a contract with `PersonActor`.

## 3) Safe workflow for edits

1. Open the level scene where the NPC exists.
2. Confirm NPC instance source prefab.
3. Confirm `definition` is assigned on the NPC instance.
4. Make one focused change (resource value or one component node).
5. Run and validate interaction in-game.

## 4) Common failure modes

### NPC does not talk
- Instance uses minimal base `person.tscn`.
- Missing `InteractablePerson` node.
- `conversation` missing in definition.

### NPC does not move/chase
- Missing `ActorMovementAIComponent`.
- Node was renamed from expected contract name.
- No target is being set by gameplay code.

### Combat calls do nothing
- Missing `ActorHealthComponent` or `ActorCombatComponent`.
- Node renamed so `PersonActor` lookup returns null.

## 5) First edits that are low risk

1. Change `opening_text` in `jerry_person_definition.tres`.
2. Increase/decrease `move_speed_meters_per_sec` and test feel.
3. Duplicate civilian prefab and remove movement component to make a static talker.
4. Duplicate hostile prefab and tune damage/cooldown only.

## 6) Rule of thumb

- Behavior bug: check prefab components first.
- Tuning issue: check person definition resource first.
- Runtime identity/persistence issue: check `person_id` and level placement.
