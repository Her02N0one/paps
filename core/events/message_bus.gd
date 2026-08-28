extends Node

## Global event dispatcher (Message Bus) for decoupled system-wide signaling.
## Used heavily to decouple UI from dynamically loaded entities like the Player.

# ==============================================================================
# Player Combat & Status Signals
# ==============================================================================

## Emitted whenever the player's health changes.
signal player_health_changed(current_health: float, max_health: float)

## Emitted when the player takes damage.
signal player_damaged(amount: float, source: Node)

## Emitted when the player's weapon fires a projectile.
signal player_weapon_fired(hit: bool, hit_position: Vector3, ammo_in_mag: int, ammo_reserve: int)

## Emitted when the player attempts to fire an empty weapon.
signal player_weapon_dry_fired(ammo_in_mag: int, ammo_reserve: int)
