# Weapon System

A comprehensive weapon management and firing system. Handles weapon stats, inventory management, firing mechanics, reloading, aiming, animations, and visual effects.

## Architecture

Five layers, each with a single responsibility:

```
Weapon                  - individual weapon instance, firing logic, animations
WeaponManager           - inventory management, weapon switching, melee combat
WeaponStats             - data resource defining weapon parameters
WeaponCache             - preloading and caching weapon scenes for performance
RecoilApplier           - camera recoil calculation and application
```

## Components

**WeaponStats** (`weapon_stats.gd`)

A Resource that describes all weapon parameters. Key field groups:

| Group | Fields | Description |
|---|---|---|
| **Basic** | `fire_rate`, `burst_fire_rate`, `fire_mode`, `available_shooting_modes`, `fire_distance`, `fire_range_damage` | Firing mechanics and rate of fire |
| **Bullets** | `clip_size`, `magazine_size`, `bullet_in_chamber`, `burst_size`, `buckshot_size`, `buckshot_spread_max_angle`, `reload_penalty` | Ammunition configuration |
| **Trigger** | `trigger_delay_enabled`, `trigger_delay` | Trigger delay mechanics |
| **Damage** | `damage`, `head_mult`, `torso_mult`, `limbs_mult` | Damage values and body part multipliers |
| **Recoil** | `max_hip_camera_kick`, `min_hip_camera_kick`, `max_aim_camera_kick`, `min_aim_camera_kick`, `snappinnes`, `return_speed`, `layered_recoil_enabled`, `non_stop_mult_enabled`, `max_non_stop_mult`, `non_stop_increase` | Camera recoil and weapon sway |
| **Position & Animation** | `procedural_animation_enabled`, `standart_position`, `aim_position`, `aim_speed`, `bob_enabled`, `sway_amplitude`, `sway_spring_stiffness` | FPS animation and positioning |
| **Shell** | `manual_shell_eject`, `shell_type`, `custom_model` | Shell casing ejection |
| **Tracer** | `use_custom_tracer`, `custom_tracer_scene` | Bullet tracer effects |
| **Sounds & Animations** | `idle_animation`, `fire_animation`, `reload_animation`, `tactical_reload_animation`, `inspect_with_ammo`, `pitch_min`, `pitch_max` | Audio and animation references |
| **UI** | `icon`, `hit_marker_standart_color`, `hit_marker_critical_color` | HUD display properties |

**WeaponManager** (`weapon_manager.gd`)

The inventory and melee system controller. Manages the `inventory_weapons_list` array and handles weapon switching, bonuses integration, and melee attacks.

Key features:
- Stores up to `max_weapons_in_inventory` (default 2) weapons
- Maintains a list of all available weapon scenes and ID mappings
- Handles weapon switching via mouse wheel, number keys, or gamepad
- Integrates with bonus system (double_tap, max_ammo, speed_cola)
- Manages melee attacks with cooldown timer
- Applies scope audio effects

Available methods:
- `add_weapon(weapon_id: int)` - add weapon to inventory, refresh mag if duplicate
- `remove_weapon(weapon_id: int)` - remove and free a weapon from inventory
- `get_current_weapon()` - return active weapon instance
- `get_inventory()` - return all weapons in inventory
- `get_weapon_id_list()` - return weapon ID lookup dictionary
- `get_random_weapon_id()` - get random weapon from available pool
- `weapon_in_inventory(weapon_id: int)` - bool check
- `_change_active_weapon(id)` - switch to weapon at index, configure raycast and camera

**Weapon** (`weapon.gd`)

Individual weapon instance handling all firing, reloading, animation, and effect logic.

Firing modes:
- `SEMI` - single shot per trigger press
- `AUTO` - continuous fire while held
- `BURST` - 3-round burst per trigger press

Internal states:
- `is_aiming` - true when scoped
- `is_reloading` - true during reload animation
- `is_tactical_reload` - true when reloading with ammo in chamber
- `is_take_out` - true during weapon draw animation
- `is_haste` - true when speed_cola bonus active

Ammunition:
- `clip` - bullets currently in magazine
- `magazine` - total bullets in reserve
- `bullet_in_chamber` - extra round added after tactical reload

Timer-based firing:
- `timer` - cooldown between shots (60 / fire_rate)
- `non_stop_timer` - tracks continuous fire for accumulating recoil
- `trigger_delay_timer` - optional delay before fire

Animation system:
- Each action has an `AnimationsPack` that can contain multiple variations
- Animations are randomly selected from the pack for variety
- Supports frame-specific bullet spawning via markers

Available methods:
- `fire()` - execute shooting logic
- `reload(tactical)` - start reload animation
- `break_reloading()` - interrupt reload (e.g., when switching weapons)
- `change_shooting_mode()` - cycle through available fire modes
- `change_visible(bool)` - show/hide weapon in FPS view
- `get_hit(damage)` - apply damage from external source

**EventBus signals** (emitted by WeaponManager and Weapon)

Lifecycle signals:
- `weapon_active(index: int)` - weapon became active in inventory
- `weapon_active_object(weapon: Weapon)` - reference to active weapon
- `weapon_changed` - emitted when switching weapons
- `weapon_add_ui(icon: Texture2D)` - new weapon added to HUD
- `weapon_remove_ui(index: int)` - weapon removed from HUD
- `weapon_added_ui(id: int, element: Control)` - HUD slot created
- `weapon_reload(is_reloading: bool)` - reload state changed
- `weapon_aim(magnifying, weapon_magnifying, speed, in_scope, transition, ease)` - aiming started/stopped
- `weapon_add_ammo(amount: int)` - add ammunition to active weapon
- `weapon_recoil(kick_vector, duration)` - apply camera kick
- `weapon_hitted(color: Color)` - bullet hit feedback for HUD
- `melee_attack` - melee attack occurred

## Firing Pipeline

```
1. Input received (mouse click or held)
2. Fire mode check (semi/auto/burst)
3. Ammo check (clip > 0)
4. Timer check (enough time passed since last shot)
5. Animation playback (fire_animation or last_fire_animation)
6. Raycast hit detection (raycast on fire, not continuous)
7. Damage calculation (base * body_part_mult * range_curve.sample(distance))
8. Shell ejection (instantiate and apply physics)
9. Tracer effect (visual bullet line)
10. Recoil application (camera kick + non-stop multiplier)
11. Ammo decrement (clip -= 1)
```

## Reload Mechanics

**Tactical Reload** (ammo in chamber)
- Triggered when clip is not empty
- Animation: `tactical_reload_animation` 
- After animation: clip += magazine_size, magazine = 0, clip capped at clip_size
- Extra bullet stays in chamber for tactical advantage

**Standard Reload** (ammo depleted)
- Triggered when clip is empty
- Animation: `reload_animation`
- If `single_loading` enabled: reload_start → reload_cycle (looped) → reload_end
- After animation: clip = magazine_size (or remaining if not enough)

**Reload Penalty** 
- If `reload_penalty = true`, leftover bullets in clip are discarded on reload
- Encourages strategic reload timing

## Animation System

Each animation action maps to an `AnimationsPack`:

```gdscript
class AnimationsPack:
    var _animations_pack: PackedStringArray  # comma-separated animation names
    
    func parse(data: String) -> void
        # "fire_1,fire_2,fire_3" → picks randomly on playback
    
    func get_rand_animation() -> String
        # Returns random animation from pack, or "null" if empty
```

Supported animation groups (all optional):
- `fire_animation` - standard fire with ammo
- `aim_fire_animation` - fire while aiming
- `last_fire_animation` - final shot before reload
- `last_aim_fire_animation` - final shot while aiming
- `idle_animation` - loop in neutral state
- `aim_idle_animation` - loop while aiming
- `reload_animation` - full reload sequence
- `tactical_reload_animation` - reload with chambered round
- `take_out_animation` - weapon draw
- `inspect_with_ammo` - inspect gun (full magazine)
- `inspect_without_ammo` - inspect gun (empty magazine)

## Damage Calculation

```
result_damage = damage * body_part_mult * fire_range_damage.sample(distance / fire_distance)

body_part_mult:
  - head_mult (default 2.0)
  - torso_mult (default 1.0)
  - limbs_mult (default 1.0)

fire_range_damage: Curve resource
  - Maps distance ratio [0..1] to damage multiplier
  - Allows realistic falloff at distance
```

## Recoil System

Two recoil modes:

**Basic Recoil**
- `max_hip_camera_kick` / `min_hip_camera_kick` - recoil range when hip-firing
- `max_aim_camera_kick` / `min_aim_camera_kick` - reduced recoil when aiming
- `snappinnes` - how fast camera snaps to kick (default 6)
- `return_speed` - how fast camera returns to center (default 2)

**Non-Stop Recoil Accumulation** (enabled by default)
- `non_stop_mult_enabled = true` - accumulation active
- Multiplier starts at `min_non_stop_mult` (default 1.0)
- Each shot increases by `non_stop_increase` (default 0.05)
- Capped at `max_non_stop_mult` (default 5.0)
- `non_stop_reset_threshold` (default 0.5s) - resets if trigger released

**Layered Recoil** (optional advanced)
- `layered_recoil_enabled = true` - use LayeredRecoil data
- `layered_recoil` - reference to custom RecoilData resource

## Weapon Sway & Bob

**Weapon Bob** (vertical/horizontal oscillation while moving)
- `bob_enabled` - toggle bob effect
- `bob_range` - amplitude of bob motion (±0.04 default)
- `bob_freq` - frequency of bob oscillation (2.3 Hz default)

**Weapon Sway** (following mouse input)
- `sway_use_custom_values` - use weapon-specific or global values
- `sway_amplitude` - response strength to mouse movement (3.0° default)
- `sway_amplitude_in_scope` - reduced amplitude when aiming (0.75° default)
- `sway_spring_stiffness` - spring constant for smoothing (300 default)
- `sway_spring_damping` - damping coefficient (22 default)
- `sway_mouse_decay` - mouse input falloff rate (32 default)
- `sway_strafe_roll_strength` - tilt when strafing (1.5 default)

## Shotgun Buckshot

For shotguns (`buckshot_size > 0`):
- `buckshot_size` - number of pellets per shot
- `buckshot_spread_max_angle` - max spread in degrees (5° default)
- Manager sets `is_manual_raycast_control = true` to handle multiple raycasts

## Bonus Integration

WeaponManager listens to `EventBus.bonus_activated` and applies effects:

| Bonus | Effect |
|---|---|
| `double_tap` | fire_rate *= 1.2, burst_fire_rate *= 1.2, melee_cooldown *= 0.8 |
| `max_ammo` | clip = clip_size, magazine = magazine_size for all weapons |
| `speed_cola` | is_haste = true (affects reload animation speed) |

## Usage

```gdscript
# Add weapon to inventory
var weapon_id : int = Global.weapon_manager.get_id_by_name("FSP45")
Global.weapon_manager.add_weapon(weapon_id)

# Get current active weapon
var current_weapon = Global.weapon_manager.get_current_weapon()

# Check if weapon is active
if Global.bonus_controller.is_bonus_active(&"double_tap"):
    # fire_rate already increased by bonus system
    var effective_firerate = current_weapon.weapon_stats.fire_rate

# Manual reload
current_weapon.reload(true)  # tactical reload

# Change fire mode
current_weapon.change_shooting_mode()

# Read weapon data
print(current_weapon.clip)  # bullets in chamber
print(current_weapon.magazine)  # bullets in reserve
```

## Dependencies

- `Global.weapon_manager` must be initialized before weapons are added
- `WeaponStats` resources must have valid animation references (or empty string to disable)
- `EventBus` must be an autoload accessible globally
- `GraphicsSettings` autoload for FOV and render settings
- Weapon scenes require proper node path exports for: AnimationPlayer, AudioStreamPlayer, OmniLight (muzzle flash), GPUParticles (smoke)
- Recoil requires valid camera nodes from player controller

## Creating a New Weapon

1. Create a `.tres` resource based on `WeaponStats` and set all parameters
2. Create a 3D scene with weapon model, animations, and audio
3. Attach a `Weapon` script, configure node path exports
4. Add registry in `WEAPON_REGISTRY ` dictionary

Example:
```gdscript
const WEAPON_REGISTRY: Dictionary = {
    # ...existing weapons...
    7: ["NEW_WEAPON", "res://player/weapons/in_game/new_weapon/new_weapon.tscn"]
}
```
