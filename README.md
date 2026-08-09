<img src="icon.png" width="80" align="right"/>

# paps

A 3D game made in [Godot 4](https://godotengine.org/).

## Controls

| Action | Key |
|--------|-----|
| Move | WASD |
| Jump | Space |
| Sprint | Shift |
| Inventory | I |
| Pause | Escape |

## Project structure

- `scripts/inventory.gd` owns inventory mutations and emits state snapshots. Gameplay and UI code use its public commands instead of editing slots directly.
- `scripts/item_data.gd` is the item behavior extension point. Item-specific resources can override `can_use()` and `use()` without adding item rules to the inventory UI.
- `scenes/inventory_panel.tscn` owns the inventory screen. `scenes/inventory_slot.tscn` is the reusable slot presentation.
- `scenes/world.tscn` is the stable in-game application shell. `GameplayWorld` contains `LevelRoot`, `EntityRoot`, and `EffectRoot`; HUD, menus, examination, inventory, and debug each have independent canvas layers.
- `scripts/world.gd` coordinates level and entity lifecycle. It adapts inventory events to the 3D world but does not own HUD or modal behavior.
- `scripts/base_level.gd` is the contract for loadable levels. Levels own local geometry, gateways, spawn points, and authored objects, but never the player.
- `scripts/game_ui_controller.gd` owns HUD, pause, examination, inventory modality, mouse capture, and UI input.
- `scripts/game_state.gd` owns runtime global and per-scene state but performs no file I/O.
- `scripts/save_manager.gd` owns binary save slots, metadata, integrity checks, and atomic file replacement.
- `scripts/settings_manager.gd` stores user preferences separately through `ConfigFile`; settings are not tied to a game slot.

Inventory selection uses stable slot IDs, so UI selection remains valid when stacks change. Add future inventory actions to the inventory API first, then have the panel call that API rather than mutating item data or slot state directly.

Save slots are written to `user://saves/slot_<n>.save`. Each binary file has a versioned header and SHA-256 payload checksum, followed by metadata, global game state, and scene-specific game state encoded with Godot's safe Variant serialization. The safe `var_to_bytes()` and `bytes_to_var()` APIs are used; the object-enabled `_with_objects` variants are never called. Temporary and backup files are used for atomic replacement.

User settings are stored separately in `user://settings.cfg` so display, audio, input, and accessibility preferences apply across all save slots.
