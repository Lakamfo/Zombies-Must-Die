# Zombies Must Die - Project Introduction

## Project Overview

Zombies Must Die is a shooter inspired by Call of Duty: Zombies, built with Godot Engine 4.6+. The whole codebase is written in GDScript and the game supports local play as well as export to multiple platforms including Windows, Linux, and Android. The core concept is straightforward: survive waves of zombies, spend points on weapons and power-ups, and see how long you can last.

The project has been in development for several years and contains a significant amount of legacy code. Throughout its lifetime, many systems were implemented using solutions that reflected the project's requirements and the developer's experience at the time. As a result, some parts of the codebase may appear unconventional or overly complex by current standards.


Prior to the 2.0 update release, a number of these legacy systems were refactored or completely rewritten. However, some older implementations remain in place either for compatibility reasons or because they continue to function reliably. When exploring the project, it is therefore possible to encounter a mixture of modernized systems and older architectural approaches.

## Project Architecture

### Folder Structure

```
Zombies-Must-Die/
├── addons/              # Godot plugins
├── android/             # Android export
├── assets/              # Shared assets and icons
├── classes/             # Core game code
│   ├── bonuses/         # Bonus system 
│   ├── components/      # Reusable components
│   ├── enemy_base.gd    # Base enemy class
│   ├── level_game_scene.gd
│   ├── map_gen/         # Map generation
│   ├── modifiers/       # Game modifiers
│   ├── wave_logic/      # Wave logic
│   └── ...
├── default_resources/   # Default resources
├── entities/            # Enemies, physics, sounds
├── docs/                # Documentation
├── localization/        # Translations (i18n)
├── map/                 # Maps and levels
├── objects/             # Interactive objects
├── player/              # Player logic
│   ├── ui/             # UI
│   ├── weapon_logic/    # Weapon system
│   ├── weapons/         # Weapon models
│   ├── player_script.gd # Player script
│   └── ...
├── scenes/              # Scenes (menus)
├── server/              # Server code
├── shaders/             # Shaders
├── singletones/         # Autoload singletons
├── sounds/              # Sounds and music
├── textures/            # Textures
├── tools/               # Utilities
├── ui/                  # UI assets
├── project.godot        # Godot config
└── README.md            # Main README
```

## Core Systems

### 1. Bonus System (classes/bonuses/)

The bonus system uses a four-layer architecture with clear separation of responsibilities. It handles both pickups and vending machines through a single unified pipeline.

```
UI (BonusUIController)       - Slot visualization
Effects (BonusEffectsManager) - Applying effects
Core (BonusController)       - State management, timers
Data (BonusRegistry)         - Bonus registry
```

**Components:**
- **BonusRegistry** (bonus_registry.gd) - stores all bonuses, lookup by ID
- **BonusController** (bonus_controller.gd) - handles activation and deactivation, manages timers automatically
- **BonusEffectsManager** (bonus_effects_manager.gd) - applies effects like double points, instant kill, etc.
- **BonusUIController** (bonus_system.gd) - renders bonus slots in the UI
- **BonusDefinition** (bonuse_definition.gd) - bonus data, supports both PICKUP and MACHINE sources

**Available bonuses:**
Vending machines (paid): quick_revive, juggernog, speed_cola, double_tap
Pickups (free): double_points, instant_kill, nuke, max_ammo, full_repair

**Usage:**
```gdscript
# Activate a bonus
Global.bonus_controller.activate_bonus("double_points")

# Check if active
if Global.bonus_controller.is_bonus_active("instant_kill"):
	print("Instant kill is active!")

# Get list of active bonuses
var active = Global.bonus_controller.get_active_bonuses()

# Get bonus info
var bonus = Global.bonus_registry.get_bonus("juggernog")
print(bonus.label, bonus.price, bonus.duration)
```

**Why this architecture works well:**
- One system handles all bonus types (pickups and machines)
- Each layer has a clear responsibility
- Easy to add new bonuses
- Straightforward to test

### 2. Weapon System (player/weapon_logic/, player/weapons/)

**WeaponManager** handles the inventory, active weapon, and reloading.

**Weapon stats include:**
- Damage, fire rate, magazine size
- Fire modes: Semi, Auto, Burst
- Camera and body recoil
- and much more...

**Available weapons:**
- MP5SD (SMG)
- FSP 45 (Pistol)
- M4A1 (Assault Rifle)
- Model 680 (Shotgun)
- MK14 (DMR)
- Revolver 6 (Revolver)
- SG552 (Rifle)
- Knife (Melee)
- Grenade (projectile)

### 3. Enemy System (classes/enemy_base.gd, entities/)

**EnemyBase** is the base class for all enemies. It covers health and armor, behavior like following and attacking, sounds for screams, pain, and death, drops like points and bonuses, and AI navigation.

**Current enemies:**
- Zombies (basic)
- Small zombies
- Explosive zombies

### 4. Wave System (classes/wave_logic/)

**WaveLogic** tracks the current wave, how many enemies are in it, how many have been killed, and what rewards the player gets at the end. Difficulty scales with each wave: more enemies, higher damage.

### 5. Player System (player/player_script.gd)

**Player** manages health, movement and jumping, interaction with objects, status effects, and score tracking.

**Components:**
- **FootstepsModule** - footstep sounds
- **InteractModule** - interaction system for buying and picking up items
- **StatusManager** - handles effects like stress
- **StatusEffects** - buffs and debuffs

### 6. EventBus (singletones/event_bus.gd)

A global signal system for communication between systems, based on the Observer pattern.

**Core bonus signals:**
```gdscript
signal bonus_activated(bonus_id: String, stacks: int)
signal bonus_refreshed(bonus_id: String)
signal bonus_deactivated(bonus_id: String)
signal bonus_purchased(bonus_id: String, price: int)
signal bonus_time_updated(bonus_id: String, time_left: float)

# Effect-specific signals (for legacy logic)
signal bonus_double_points
signal bonus_instant_kill
signal bonus_double_points_expired
signal bonus_instant_kill_expired
signal bonus_full_repair
signal bonus_nuke_all
signal bonus_full_ammo
signal bonus_juggernog
signal bonus_quick_revive
signal bonus_speed_cola
signal bonus_double_tap
```

**Other signals:**
```gdscript
# Weapons
signal weapon_fired(weapon: Weapon)
signal weapon_reload(is_reloading: bool)
signal weapon_add_ammo(amount: int)
signal weapon_fire_mode_changed(fire_mode: int)

# Enemies
signal game_enemy_killed
signal enemy_spawned(enemy: Node)

# Waves
signal wave_started(wave: int)
signal wave_ended(wave: int)

# Player
signal player_die
signal player_revived()
signal player_changed_health(health: float, old_health: float)
signal add_score(line: String, score: int)

# UI
signal ui_message(message: String)
signal ui_update_score(score: int)
signal ui_update_interactable(description: String)
signal ui_update_wave(wave: int)
```

### 7. Singletons (singletones/)

Autoloaded global managers:
- **Global** - main singleton (player, weapon_manager, bonus_registry, bonus_controller)
- **GameState** - game state (current location, score, records)
- **EventBus** - signal system
- **InputSettings** - input settings (sensitivity, axis inversion)
- **GraphicsSettings** - graphics settings (quality, FOV)
- **SceneManager** - scene management (loading, transitions)
- **ServerRequests** - server requests (leaderboards, stats)
- **BloodManager** - blood system
- **DebugOutput** - debug output
- **MouseManager** - mouse handling (locking, showing)
- **SystemInfo** - system info (sensors, platform)
- **MaterialsBank** - material cache
- **StreamBank** - audio stream cache
- **WeaponCache** - as it said

### 8. Localization System (localization/)

Multiple language support through the tr() function. Keys follow the format: KEY_BONUS_DOUBLE_POINT, KEY_WAVE, KEY_OBJECT_BUY_HINT, etc.

```gdscript
label.text = tr("KEY_WAVE") % wave_number
```

### 9. Map System (map/, classes/map_gen/)

Map generation includes a NavigationMesh for bots and enemies, enemy spawns for waves and individual encounters, pickup spawns, interactive objects like doors, electricity and vending machines, player spawns, and environment objects.

### 10. Network System (server/)

The server handles saving records, player statistics, leaderboards, and data sync. The stack is Python with Flask.

## Game Flow

### 1. Main Menu
```
main_menu.tscn -> (Press "Play") -> Map selection
```

### 2. Level Initialization (LevelGameScene._ready())
```
LevelGameScene._ready()
├── GameState.current_location_root = self
├── Initialize weapon_manager
├── Initialize wave_logic
├── ServerRequests.start_run()
└── Connect event handlers
```

### 3. Game Loop (each frame)
```
_(physics_)process(delta)
├── Update player (movement, interaction)
├── Update enemies (AI, attack, death)
├── Update weapons (reload, recoil, ammo)
├── Update bonuses (BonusController timers)
├── Update UI (score, health, bonuses)
└── Check conditions (player death, wave complete)
```

### 4. When a player picks up a pickup
```
Pickup._on_body_entered(player)
└── Global.bonus_controller.activate_bonus("bonus_id")
	├── Check: already active?
	├── Add to _active_bonuses
	├── Emit signal bonus_activated
	│   ├── BonusUIController shows slot
	│   └── BonusEffectsManager applies effect
	│       ├── Emit bonus_double_points (if double_points)
	│       ├── Emit bonus_instant_kill (if instant_kill)
	│       └── ...
	├── _process() automatically counts down the timer
	└── At 0: calls deactivate_bonus()
```

### 5. When a player buys from a machine
```
VendingMachine.action()
├── Check electricity (if required)
├── Check funds (player.score >= price)
├── Global.bonus_controller.activate_bonus("bonus_id")
├── Emit signal bonus_purchased
├── EventBus.emit_signal("add_score", message, -price)
└── UI updates and sound plays
```

### 6. When a wave ends
```
WaveLogic.check_wave_completion()
└── If all enemies are dead:
	├── Emit wave_ended
	├── Show wave bonus
	└── Start next wave
```

## Key Classes

### Player (player/player_script.gd)
```gdscript
class_name Player
extends CharacterBody3D

var health: float
var max_health: float
var score: int
var weapon_manager: WeaponManager
var velocity: Vector3
var camera_3d: Camera3D

func take_damage(damage: float) -> void:
	health -= damage
	EventBus.player_changed_health.emit(health, health + damage)

func heal(amount: float) -> void:
	health = min(health + amount, max_health)

func add_score(amount: int) -> void:
	score += amount
	EventBus.ui_update_score.emit(score)

func die() -> void:
	EventBus.player_die.emit()
	# Show death screen
```

### WeaponManager (player/weapon_logic/weapon_manager.gd)
```gdscript
class_name WeaponManager
extends Node3D

var inventory_weapons_list: Array  # Array[Weapon]
var active_weapon: int = 0

func add_weapon(weapon_id: int) -> void:
	# Add weapon to inventory

func switch_weapon(index: int) -> void:
	# Switch to weapon

func get_current_weapon() -> Weapon:
	return inventory_weapons_list[active_weapon]
```

### Enemy (classes/enemy_base.gd)
```gdscript
class_name EnemyBase
extends CharacterBody3D

var health: float
var damage: float
var target: Player

func take_damage(damage: float) -> void:
	health -= damage
	if health <= 0:
		die()

func attack() -> void:
	# Attack the player

func die() -> void:
	EventBus.game_enemy_killed.emit()
	queue_free()
```

### WaveLogic (classes/wave_logic/wave_logic.gd)
```gdscript
class_name WaveLogic
extends Node

var current_wave: int = 1
var wave_progress: int = 0  # How many enemies killed

func start_wave() -> void:
	wave_progress = 0
	EventBus.wave_started.emit(current_wave)
	# Spawn enemies

func get_enemies_for_wave(wave: int) -> int:
	return 6 + wave * 2  # 8, 10, 12, ...

func is_wave_complete() -> bool:
	return wave_progress >= get_enemies_for_wave(current_wave)
```

### BonusController (classes/bonuses/bonus_controller.gd)
```gdscript
class_name BonusController
extends Node

var _active_bonuses: Dictionary = {}  # id -> {definition, stacks, time_left}

func activate_bonus(bonus_id: String) -> bool:
	# Activate bonus, check stacking
	# Emit bonus_activated

func deactivate_bonus(bonus_id: String) -> bool:
	# Deactivate bonus
	# Emit bonus_deactivated

func is_bonus_active(bonus_id: String) -> bool:
	return _active_bonuses.has(bonus_id)

func _process(delta: float) -> void:
	# Automatically counts down timers and deactivates bonuses
```

## Extending the Project

### Adding a new weapon
1. Create a weapon scene in player/weapons/gun_name/
2. Inherit from Weapon
3. Define weapon_stats (damage, fire rate, magazine)
4. Add to WeaponManager.all_weapons_list, all_weapons_id_const, all_weapons_string
5. Add model and animations in weapon scene

you can look how other weapons is done.

### Adding a new bonus
1. Create a BonusDefinition resource or define it in code
2. Register it in BonusRegistry._load_bonuses()
3. Add the effect to BonusEffectsManager.apply_bonus_effect(bonus_id)
4. Optionally add a UI icon

```gdscript
# Bonus define in code
var bonus = BonusDefinition.new()
bonus.id = &"my_bonus"
bonus.label = "My Bonus"
bonus.source = BonusDefinition.Source.PICKUP
bonus.duration = 20.0
Global.bonus_registry.register_bonus(bonus)
```

### Adding a new enemy
1. Create a scene that inherits from EnemyBase
2. Define behavior (AI, attack) and health
3. Add sounds and animations
4. Create WaveLogicEnemy resource and configure it
5. Add to WaveLogic spawns
6. Configure drops (points, bonus chance)

### Adding a new level
1. Create a scene in map/ (additional resources in map/{map-name})
2. Add a navmesh (NavigationRegion3D)
3. Add enemy, pickup, and machine spawns
4. Set up the environment (lighting, textures, objects)
5. Create LocationData resource in map/data
6. Configure resource

## Running the Project

### Requirements
- Godot Engine 4.6+
- Blender 5.2+ (for importing 3D models)
- Python 3.9+ (optional, for the server)
- OS: Windows, macOS, Linux

### Setup steps

1. Open in Godot

2. Set the Blender path with first open or set in: Editor -> Editor Settings -> Blender Path, then point it to the Blender executable (filesystem/import/blender/blender_path).

3. Rename the secret file if needed:
```bash
cp res://classes/secret/secret_example.gd res://classes/secret/secret.gd
```

4. Run the game: press F5 or click Play, or open the scene at res://scenes/main_menu/main_menu.tscn directly.

### Running the server
```bash
cd server/
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
python3 main.py
```
The server listens on http://localhost:5000

## Key Files to Know

| File | Purpose | Priority |
|------|---------|----------|
| project.godot | Godot config | * |
| singletones/global.gd | Main singleton | ** |
| singletones/event_bus.gd | Signal bus | ** |
| player/player_script.gd | Player logic | ** |
| player/weapon_logic/weapon_manager.gd | Weapon manager | ** |
| classes/bonuses/bonus_controller.gd | Bonus controller | ** |
| classes/wave_logic/wave_logic.gd | Wave logic | ** |
| classes/level_game_scene.gd | Main level scene | ** |
| scenes/main_menu/main_menu.tscn | Main menu | * |
| classes/bonuses/README.md | Bonus system docs | * |
| classes/interactable_item.gd | Interactable objects | * |

## Signal System (EventBus)

EventBus is used for loose coupling between components using the Observer pattern.

```gdscript
# Subscribe to an event
EventBus.bonus_activated.connect(my_callback_function)

# Unsubscribe (optional)
EventBus.bonus_activated.disconnect(my_callback_function)

# Emit an event
EventBus.bonus_activated.emit("double_points", 1)

# Event handler
func my_callback_function(bonus_id: String, stacks: int):
	print("Bonus activated: %s, stacks: %d" % [bonus_id, stacks])

# Lambda version
EventBus.bonus_activated.connect(func(bonus_id, stacks):
	print("Bonus activated: %s" % bonus_id)
)
```

**Why EventBus is worth using:**
- Components do not depend on each other directly
- Easy to add new listeners without touching existing code
- No circular dependencies
- Much easier to test individual systems in isolation

## Code Conventions

### Variable naming
```gdscript
var my_variable: int                # Variables - snake_case
var CONSTANT_VALUE: int = 42        # Constants - UPPER_SNAKE_CASE
const MY_CONST = 100                # const - UPPER_SNAKE_CASE
@onready var my_node: Node          # @onready - snake_case
@export var my_export: int          # @export - snake_case
@export_group("Group Name")         # Export grouping
```

### Code organization (most of existing code is not folowing this :<)
```gdscript
class_name MyClass
extends BaseClass

#region Signals
signal my_signal(param: String)
#endregion

#region Exports
@export var my_property: int
@export_group("Advanced")
@export var advanced_property: bool
#endregion

#region Variables
var my_variable: String
var _private_variable: String       # _ prefix for private vars
#endregion

#region Onready variables
@onready var my_node: Node
#endregion

#region Lifecycle methods
func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	pass
#endregion

#region Public methods
func public_method() -> void:
	pass
#endregion

#region Private methods
func _private_method() -> void:
	pass
#endregion

#region Event handlers
func _on_event_name() -> void:
	pass
#endregion
```

### Typing

Always specify types for function parameters, return values, and local variables:
```gdscript
func my_function(param1: int, param2: String) -> bool:
	var result: int = 42
	return true
```

## Debugging

### Using DebugOutput
```gdscript
DebugOutput.print_info("Info message")
DebugOutput.print_warning("Warning")
DebugOutput.print_error("Error")

# Output is also visible in the Godot Output panel
```

### Debugging in the editor
- **Remote Tab** - inspect live objects while the game is running
- **Debugger** - set breakpoints and step through code
- **Output Panel** - see all errors and print statements
- **Profiler** - analyze performance

### Checking bonuses
```gdscript
print(Global.bonus_controller.get_active_bonuses())
print(Global.bonus_controller.is_bonus_active("double_points"))
print(Global.bonus_registry.get_bonus("juggernog").price)
```

## Learning Resources

### Official documentation
- [Godot Official Docs](https://docs.godotengine.org/)
- [GDScript Documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)

### Project documentation
- docs/systems/ - additional system documentation
- server/README.md - server documentation
- README files in individual folders where they exist


## Getting Started as a New Developer

Follow this path in order. Times are rough estimates.

1. Run the game and just play it (15 min)
2. Open main_menu.tscn in the editor and poke around (15 min)
3. Look at scenes/warehouse.tscn to see how a level is set up (15 min)
4. Read through player/player_script.gd and trace the flow (30 min)
5. Study classes/bonuses/ as a solid example of clean architecture (1 hour)
6. See how EventBus connects everything together (30 min)
7. Try adding a simple bonus from scratch (1-2 hours)
8. At this point you should have a decent mental model of the project. From here, read existing system code as questions come up, use EventBus for all cross-system communication, follow the coding conventions, and commit often with clear messages.

## Practical Tips

1. **Use search** - Ctrl+F/Ctrl+Shift+F in the editor to find where functions are used
2. **Comment your code** - especially complex logic
3. **Test often** - run the game after every meaningful change
4. **Use Git** - commit frequently with clear messages
5. **Read existing code** - it is the best way to understand how things fit together

## Key Design Patterns

### Model-View-Controller (MVC)

The system is divided into layers:
- **Model** (BonusRegistry, BonusController) - logic and state
- **View** (BonusUIController) - rendering
- **Controller** (EventBus) - communication between layers

### Observer Pattern (EventBus)

Components do not know about each other directly. Everything communicates through EventBus signals. This loose coupling makes the codebase much easier to maintain and extend.

### Singleton Pattern (Global, GameState)

One instance per object, accessible globally by class name. Used for shared state that needs to be available everywhere.

## Performance

### General tips
- Use @onready for lazy initialization
- Cache frequently used references
- Use process_mode to control which nodes update when
- Profile before optimizing

### Profiling
- Use in game debug info menu (press F3)
- Use the Profiler in Godot (Debug -> Profiler)
- Watch FPS and frame time
- Use Debug Draw for visual debugging

## Checklist Before You Start

- [ ] Godot 4.6+ is installed
- [ ] Blender 5.2+ is installed
- [ ] Project opens without errors
- [ ] Game runs (F5)
- [ ] Main menu is visible
- [ ] A level loads
- [ ] Enemies spawn and attack
- [ ] Weapons work
- [ ] Bonuses activate

If everything is checked off, you are ready to start developing.

---

Documentation version: 0.1
Last updated: 2026-05-27
Engine: Godot Engine 4.6.2+
Language: GDScript, Python, GDSL
Status: Actively developed
