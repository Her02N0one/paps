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

## Project structure

- `scripts/features/inventory/inventory.gd` controls all changes to the inventory. The inventory sends copies of its data to other systems. Gameplay code and UI code use the public inventory functions. Gameplay code and UI code do not change slots directly.
- `scripts/features/inventory/item_data.gd` defines the data and behavior of an item. An item resource can override `can_use()` and `use()`. Thus, the inventory UI does not contain rules for specific items.
- `scenes/ui/panels/inventory_panel.tscn` contains the inventory screen. `scenes/ui/widgets/inventory_slot.tscn` contains the reusable slot control.
- `scenes/world.tscn` contains the game while play is in progress. `GameplayWorld` contains `LevelRoot`, `EntityRoot`, and `EffectRoot`. Each UI group has a separate canvas layer.
- `scripts/features/world/world.gd` controls the loading and removal of levels and entities. The world controller sends inventory events to the 3D world. The world controller does not control the HUD or menus.
- `scripts/features/world/base_level.gd` defines the interface for levels that the game can load. A level contains its geometry, gateways, spawn points, and placed objects. A level does not contain the player.
- `scripts/features/ui/game_ui_controller.gd` controls the HUD, pause menu, examination screen, and inventory screen. The UI controller also controls the mouse and UI input.
- `scripts/features/persistence/game_state.gd` contains global state and state for each scene. The game state does not read or write files.
- `scripts/features/persistence/save_manager.gd` controls binary save slots. The save manager also controls metadata, file checks, and file replacement.
- `scripts/features/persistence/settings_manager.gd` stores user settings in a `ConfigFile`. These settings are not part of a game slot.
- `scripts/context/root_context.gd` is the composition root for service lifetime and active context switching.

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
