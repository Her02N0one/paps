<img src="icon.png" width="80" align="right"/>

# paps

Paps is a 3D game made with [Godot 4](https://godotengine.org/).

## Controls

| Action | Key |
|--------|-----|
| Move | WASD |
| Jump | Space |
| Sprint | Shift |
| Interact | E |
| Inventory | I |
| Pause | Escape |

## Project ontology

The project is organized by role, not by file type.

| Path | What it is | What belongs there | What does not belong there |
|------|------------|--------------------|-----------------------------|
| `scripts/context/` | Runtime context boundary | Composition roots, service lifetime, mode switching | Feature logic details, item/world/dialogue rules |
| `scripts/features/` | Reusable gameplay capability | Inventory, world loading, dialogue flow, persistence, UI behavior | Cross-context bootstrapping and global wiring |
| `scripts/tools/` | Authoring and editor support | `@tool` scripts and generation helpers | Runtime gameplay flow |
| `scenes/` | Composition and prefab boundaries | Root contexts, world roots, UI panels, entities | Persistent game data |
| `resources/` | Authored gameplay data | Dialogue graphs, item definitions, speaker profiles | Runtime service wiring |
| `assets/` | Raw media and theme assets | Audio, textures, visual themes | Gameplay state or behavior logic |
| `tests/` | Executable behavior checks | Contract, integration, and feature tests | Production runtime wiring |

Dependency direction:

- Context scripts can call feature scripts.
- Feature scripts do not call context scripts.
- Scenes compose scripts and resources.
- Resources provide data to scripts.
- Tools can read project data but are not required by runtime contexts.

Concrete examples:

- `scripts/context/root_context.gd` is the composition root for service lifetime and active context switching.
- `scripts/features/world/world.gd` controls loading and unloading levels and entities during play.
- `scripts/features/world/base_level.gd` defines the level contract (geometry, gateways, spawn points, placed objects) without owning the player.
- `scripts/features/inventory/inventory.gd` owns inventory mutations; other systems use its public API.
- `scripts/features/persistence/game_state.gd` owns runtime state; `scripts/features/persistence/save_manager.gd` owns slot serialization and integrity checks.
- `scripts/features/persistence/settings_manager.gd` stores cross-save user settings in `ConfigFile`.
- `scenes/ui/panels/inventory_panel.tscn` and `scenes/ui/widgets/inventory_slot.tscn` define inventory UI composition.
- `scenes/world/world_root.tscn` is the in-run world root with layered gameplay and UI structure.

## Save files

The game writes save slots to `user://saves/slot_<n>.save`. Each save file contains these parts:

1. A header with a format version.
2. A SHA-256 checksum for the data.
3. Save metadata.
4. Global game state.
5. State for each scene.


## User settings

The game writes user settings to `user://settings.cfg`. Display, audio, input, and accessibility settings apply to all save slots.

## Dialogue

Dialogue is authored as Resource graphs with nodes, choices, conditions, effects, speaker profiles, voice lines, and typewriter flavor.
