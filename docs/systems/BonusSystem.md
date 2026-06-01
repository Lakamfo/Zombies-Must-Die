# Bonus System

A bonus system. Handles activation, display, and effects of bonuses the player receives by picking them up or purchasing them from a vending machine.

## Architecture

Four layers, each with a single responsibility:

```
BonusUIController      - HUD slots, animations, labels
BonusEffectsManager    - applies and removes actual game effects
BonusController        - state, timers, stacking, purchase logic
BonusRegistry          - stores and serves BonusDefinition resources
```

## Components

**BonusDefinition** (`bonus_definition.gd`)

A Resource that describes a bonus. Key fields:

| Field | Description |
|---|---|
| `id` | Unique StringName identifier |
| `label` | Display name shown in HUD |
| `source` | `PICKUP` or `MACHINE` |
| `endless` | If true, the bonus is instant with no timer |
| `duration` | Active time in seconds (if not endless) |
| `price` | Cost in points (MACHINE bonuses only) |
| `stackable` | Whether the bonus can be applied multiple times |
| `max_stacks` | Stack cap when stackable |
| `color`| Color shown in the HUD slot |
| `icon` | Texture shown in the HUD slot |
| `mesh` | 3D mesh used in the world (for pickups) |

**BonusRegistry** (`bonus_registry.gd`)

Loads all bonus resources at startup and provides lookup by id or source. All `.tres` files are registered in `_load_bonuses()`. Available methods:

- `register_bonus(bonus)` - add a new bonus to the registry
- `get_bonus(id)` - get a definition by id
- `get_bonuses_by_source(source)` - all PICKUP or all MACHINE bonuses
- `get_random_pickup_bonus()` - random bonus from the PICKUP pool
- `is_registered(id)` - check if a bonus exists

**BonusController** (`bonus_controller.gd`)

The main entry point for everything bonus-related. Manages the `_active_bonuses` dictionary and runs a `_process` loop that ticks down timers and deactivates expired bonuses.

Activation rules:
- First activation - creates an entry with `stacks: 1` and `time_left: duration`
- Already active + `stackable` + under `max_stacks` - increments stack count
- Already active + not stackable - resets `time_left` (refresh)
- Already active + stackable + at cap - returns false, does nothing

If the bonus is not `endless`, `BonusEffectsManager.apply_bonus_effect()` is called on first activation.

Available methods:
- `activate_bonus(bonus_id)` - activate or stack a bonus
- `deactivate_bonus(bonus_id)` - remove and clean up
- `try_purchase_bonus(bonus_id, player_score)` - validates source and price, then activates
- `is_bonus_active(bonus_id)` - bool check
- `get_active_bonuses()` - array of active ids
- `get_bonus_data(bonus_id)` - returns the internal dict `{ definition, stacks, time_left }`

**BonusEffectsManager** (`bonus_effects_manager.gd`)

Static node. Translates a bonus id into an EventBus signal call. No state - just a match statement.

- `apply_bonus_effect(bonus_id)` - emit the effect signal
- `remove_bonus_effect(bonus_id)` - emit the expiry signal (only for bonuses that need cleanup)

**BonusUIController** (`bonus_ui_controller.gd`)

Listens to EventBus and manages `BonusSlot` instances in the HUD. Requires two exported `HBoxContainer` references - one for pickups, one for machine bonuses. Slots handle their own exit animation and `queue_free()` internally.

## EventBus signals

Lifecycle signals (emitted by BonusController):

- `bonus_activated(bonus_id, stacks)` - on first activation or stack added
- `bonus_refreshed(bonus_id)` - timer reset for a non-stackable active bonus
- `bonus_deactivated(bonus_id)` - bonus removed
- `bonus_purchased(bonus_id, price)` - before activation, for score deduction
- `bonus_time_updated(bonus_id, time_left)` - every frame while a timed bonus is active

Effect signals (emitted by BonusEffectsManager, consumed by gameplay systems):

- `bonus_double_points` / `bonus_double_points_expired`
- `bonus_instant_kill` / `bonus_instant_kill_expired`
- `bonus_nuke_all`, `bonus_full_ammo`, `bonus_full_repair`
- `bonus_quick_revive`, `bonus_juggernog`, `bonus_speed_cola`, `bonus_double_tap`

## Adding a new bonus

1. Create a `.tres` resource based on `BonusDefinition` and set all fields.
2. Register it in `BonusRegistry._load_bonuses()`:
   ```gdscript
   register_bonus(preload("res://path/to/my_bonus.tres"))
   ```
3. Add effect logic in `BonusEffectsManager`:
   ```gdscript
   static func apply_bonus_effect(bonus_id: StringName) -> void:
	   match bonus_id:
		   &"my_bonus":
			   EventBus.my_bonus_signal.emit()

   static func remove_bonus_effect(bonus_id: StringName) -> void:
	   match bonus_id:
		   &"my_bonus":
			   EventBus.my_bonus_expired.emit()
   ```

For instant bonuses (like juggernog or revive), set `endless = true` - the effect fires once on activation and there is nothing to remove.

## Usage

```gdscript
# Activate from a pickup
Global.bonus_controller.activate_bonus(&"double_points")

# Purchase from a vending machine
Global.bonus_controller.try_purchase_bonus(&"juggernog", player_score)

# Check state anywhere
if Global.bonus_controller.is_bonus_active(&"instant_kill"):
	damage *= 9999

# Read timer/stacks
var data = Global.bonus_controller.get_bonus_data(&"double_points")
print(data[&"time_left"], data[&"stacks"])
```

## Dependencies

- `Global.bonus_registry` and `Global.bonus_controller` must be initialized before any scene that uses bonuses.
- `BonusEffectsManager` must be present in the scene tree as a node (it sets `_instance` in `_ready`).
- `EventBus` must be an autoload accessible globally.
- Scenes clear active bonuses automatically on `EventBus.scene_changed`.
