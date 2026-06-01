# Modifier System

A lightweight event-driven modifier framework that adjusts gameplay mechanics based on selected modifiers. Handles modifier registration, activation, and event-based effect application across all game systems.

## Architecture

Two layers with a single responsibility each:

```
ModifiersManager     - registry, activation, event dispatch
BaseModifier         - interface for individual modifier behavior
```

## Components

**ModifiersManager** (`modifiers_manager.gd`)

Static manager node that maintains the modifier registry and active modifier instances. All modifier logic flows through a single event dispatch point.

Registry structure:
```gdscript
static var modifier_registry: Dictionary = {
    Modifiers.FastZombiesModifier: {
        "script": preload("res://path/to/fast_zombies_modifier.gd"),
        "display_name": "Fast Zombies"
    },
    Modifiers.SmallZombiesOnlyModifier: {
        "script": preload("res://path/to/small_zombies_only_modifier.gd"),
        "display_name": "Small Zombies Only"
    }
}
```

Active modifiers dictionary:
```gdscript
static var active_modifiers: Dictionary[Modifiers, BaseModifier] = {}
```

Available methods:

| Method | Parameters | Description |
|---|---|---|
| `create_modifier(modifier)` | `Modifiers` enum value | Create instance of modifier class, return null if not found |
| `get_modifier_name(modifier)` | `Modifiers` enum value | Get display name from registry |
| `clear_active_modifiers()` | none | Clear all active modifiers dictionary |
| `add_active_modifier(modifier, instance)` | `Modifiers` enum, `BaseModifier` instance | Add active modifier to dictionary |
| `trigger_event(event_name, data)` | `StringName` event, optional `Dictionary` data | Dispatch event to all active modifiers |

**BaseModifier** (`base_modifier.gd`)

Abstract base class for all modifiers. Extends `RefCounted` for automatic memory management.

```gdscript
class_name BaseModifier
extends RefCounted

var modifier_name: StringName = &"Base"

func apply(_event_name: StringName, _data: Dictionary) -> void:
    # Override this method in subclasses
    pass
```

Properties:
- `modifier_name` - StringName identifier for the modifier

Methods:
- `apply(event_name, data)` - Called when modifier receives a triggered event

## Current Modifiers

**FastZombiesModifier** (`fast_zombies_modifier.gd`)

Increases zombie difficulty by boosting speed and attack speed.

Triggers on: `&"enemy_spawned"`

Effects:
- `enemy.speed *= 2` - doubles movement speed
- `enemy.attack_threshold_time /= 1.2` - increases attack frequency by 20%

```gdscript
func apply(event_name: StringName, data: Dictionary) -> void:
    if event_name == &"enemy_spawned":
        var enemy = data.enemy
        if &"speed" in enemy:
            enemy.speed *= 2
        if &"attack_threshold_time" in enemy:
            enemy.attack_threshold_time /= 1.2
```

**SmallZombiesOnlyModifier** (`small_zombies_only_modifier.gd`)

Restricts zombie spawns to small zombies only.

Triggers on: Manual integration in `LevelGameScene._ready()`

Integration:
```gdscript
if wave_logic:
    wave_logic.small_zombies_only = ModifiersManager.active_modifiers.has(
        ModifiersManager.Modifiers.SmallZombiesOnlyModifier
    )
```

**LondonModifier** (`london_modifier.gd`)

Disables vending machines and mystery boxes, restricts starting weapons.

Triggers on: Manual integration in `LevelGameScene._ready()`

Integration:
```gdscript
if player:
    if not ModifiersManager.active_modifiers.has(ModifiersManager.Modifiers.LondonModifier):
        # Normal game: add FSP45 starting weapon
        weapon_manager.add_weapon(weapon_manager.all_weapons_id_const.FSP45)
    else:
        # London mode: remove all vending machines
        if mystery_box: mystery_box.queue_free()
```

## Event System

Modifiers respond to named events dispatched via `ModifiersManager.trigger_event()`.

Standard events:

| Event | Data Dictionary | Description |
|---|---|---|
| `&"enemy_spawned"` | `{ "enemy": Enemy }` | Fired when zombie spawns (before entering arena) |
| Custom events | Varies | Game systems can trigger custom events |

Event dispatch example:
```gdscript
# From enemy spawner
ModifiersManager.trigger_event(&"enemy_spawned", { "enemy": zombie_instance })

# All active modifiers receive this event simultaneously
```

## Modifier Lifecycle

```
1. Modifier registered in ModifiersManager.modifier_registry
2. Modifier selected by player or set by default
3. ModifiersManager.create_modifier() creates instance
4. ModifiersManager.add_active_modifier() stores in active_modifiers dict
5. Game systems call ModifiersManager.trigger_event()
6. All active modifiers' apply() methods called with event
7. On scene change/game end: ModifiersManager.clear_active_modifiers()
```

## Creating a New Modifier

1. Create a new script extending `BaseModifier`:

```gdscript
# res://classes/modifiers/my_new_modifier.gd
extends BaseModifier
class_name MyNewModifier

func _init() -> void:
    modifier_name = &"My New Modifier"

func apply(event_name: StringName, data: Dictionary) -> void:
    match event_name:
        &"enemy_spawned":
            var enemy = data.enemy
            enemy.health *= 1.5  # 50% harder
        &"custom_event":
            # Handle custom events
            pass
```

2. Register the modifier in `ModifiersManager`:

```gdscript
# modifiers_manager.gd
enum Modifiers {
    BaseModifier,
    LondonModifier,
    FastZombiesModifier,
    SmallZombiesOnlyModifier,
    MyNewModifier  # Add here
}

static var modifier_registry: Dictionary = {
    # ...existing modifiers...
    Modifiers.MyNewModifier: {
        "script": preload("res://classes/modifiers/my_new_modifier.gd"),
        "display_name": "My New Modifier"
    }
}
```

3. (Optional) Integrate with game systems in `LevelGameScene._ready()`:

```gdscript
if ModifiersManager.active_modifiers.has(ModifiersManager.Modifiers.MyNewModifier):
    # Configure game for this modifier
    some_system.setting = true
```

## Integration Points

**Level Initialization** (`LevelGameScene._ready()`)

Checks for specific modifiers and configures the scene:

```gdscript
# Log active modifiers
var mod_active_names := []
for modifier in ModifiersManager.active_modifiers.keys():
    mod_active_names.append(ModifiersManager.get_modifier_name(modifier))
DebugOutput.print_info('Active Modifiers : ' + str(mod_active_names))

# London Modifier: disable starting weapon and vending
if not ModifiersManager.active_modifiers.has(ModifiersManager.Modifiers.LondonModifier):
    weapon_manager.add_weapon(weapon_manager.all_weapons_id_const.FSP45)
else:
    if mystery_box: mystery_box.queue_free()

# Small Zombies Only: configure wave spawner
wave_logic.small_zombies_only = ModifiersManager.active_modifiers.has(
    ModifiersManager.Modifiers.SmallZombiesOnlyModifier
)
```

**Enemy Spawning** (Enemy Spawner)

Triggers modifier events when enemies enter the arena:

```gdscript
# In enemy spawner or wave logic
var zombie = spawn_zombie(zombie_type)
ModifiersManager.trigger_event(&"enemy_spawned", { "enemy": zombie })
```

## Usage Patterns

**Check if modifier is active:**
```gdscript
if ModifiersManager.active_modifiers.has(ModifiersManager.Modifiers.FastZombiesModifier):
    # Run difficulty-appropriate logic
    spawn_more_zombies()
```

**Get all active modifier names:**
```gdscript
var active_names = []
for modifier in ModifiersManager.active_modifiers.keys():
    active_names.append(ModifiersManager.get_modifier_name(modifier))
print("Active modifiers: ", active_names)
```

**Activate modifiers at game start:**
```gdscript
ModifiersManager.clear_active_modifiers()

# Select modifiers (e.g., from user selection UI)
var selected_modifiers = [
    ModifiersManager.Modifiers.FastZombiesModifier,
    ModifiersManager.Modifiers.SmallZombiesOnlyModifier
]

for modifier_type in selected_modifiers:
    var instance = ModifiersManager.create_modifier(modifier_type)
    if instance:
        ModifiersManager.add_active_modifier(modifier_type, instance)
```

**Trigger custom events from game systems:**
```gdscript
# From player script when taking damage
ModifiersManager.trigger_event(&"player_damaged", { "damage": damage_amount })

# From score system
ModifiersManager.trigger_event(&"points_earned", { "points": 100 })
```

## Design Patterns

**Event-Driven Design**

Modifiers never directly modify game systems. Instead, systems emit events that modifiers listen to and respond to. This keeps modifiers loosely coupled from the rest of the codebase.

**Registry Pattern**

The `modifier_registry` dictionary allows modifiers to be registered centrally without coupling the manager to specific modifier implementations. New modifiers can be added by updating the registry only.

**Passive Modification**

Modifiers don't have update loops or timers. They only respond to events. This keeps memory and CPU usage minimal when modifiers are active.

## Dependencies

- `ModifiersManager` must be initialized as an autoload (or at least before level scenes load)
- Event sources (enemy spawner, player, etc.) must call `ModifiersManager.trigger_event()` at appropriate points
- `LevelGameScene` should check for modifiers in `_ready()` to configure initial scene state

## Best Practices

1. **Use StringName for event names** - faster comparison than String
2. **Include full data in event dict** - modifiers should not need to query other systems
3. **Check if property exists before accessing** - use `if &"property" in object:` pattern
4. **Avoid side effects** - modifiers should only transform incoming data, not trigger other events
5. **Keep modifiers independent** - active modifiers should not interfere with each other
6. **Document expected data structure** - include event.data shape in modifier comments

## Example: Complete Modifier Implementation

```gdscript
# res://classes/modifiers/hardcore_modifier.gd
extends BaseModifier
class_name HardcoreModifier

# Removes all bonuses from the game

func _init() -> void:
    modifier_name = &"Hardcore"

func apply(event_name: StringName, data: Dictionary) -> void:
    match event_name:
        &"bonus_spawned":
            # Prevent bonus from appearing
            var bonus = data.bonus
            bonus.queue_free()
        
        &"player_purchased_bonus":
            # Reject purchase
            var player_score = data.player_score
            data.purchase_successful = false
```
