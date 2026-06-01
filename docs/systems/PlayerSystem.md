# Player System

A comprehensive first-person controller featuring a finite state machine for movement, health and stamina management, camera control with bobbing, weapon integration, and character physics with stairs stepping and body collision physics.

## Architecture

Three specialized layers with clear separation of concerns:

```
Player (player_script_FSM.gd)      - Main character controller, health, score, camera
State Machine                       - Movement state transitions and logic
PlayerMovementState (base)          - Shared movement utilities for all states
  ├── IdlePlayerState               - No movement
  ├── WalkingPlayerState            - Normal movement
  ├── RunningPlayerState            - Sprint with stamina drain
  ├── CrouchingPlayerState          - Reduced height, slower speed
  ├── JumpingPlayerState            - Upward velocity, directional boost
  ├── FallingPlayerState            - Gravity only, fall damage
  ├── LyingDownPlayerState          - Incapacitated state, revive mechanic
  └── UiPlayerState                 - Input blocked during UI interaction
```

## Components

**Player** (`player_script_FSM.gd`)

Main character controller extending CharacterBody3D. Manages all non-movement-specific systems: health, stamina, score, camera control, and weapon integration.

### Stats & Health

```gdscript
@export var max_health: float = 100
@export var health: float = 100:
    set(value):
        EventBus.signal("player_changed_health", value, health)
        health = value
        if is_laying_down and health <= 0:
            EventBus.player_die.emit()

@export var heal_time_delay: float = 5.0
@export var heal_per_second: float = 3
@export var heal_curve: Curve              # Damage curve for healing ramp
@export var time_to_revive: float = 10     # Time to auto-revive with quick_revive bonus
```

Health system:
- Healing starts after 5 seconds without damage (delay-based)
- Uses heal_curve to ramp healing speed over time
- Quick-revive bonus auto-revives in 5 seconds when laying down
- Death threshold: health <= 0 while laying down

### Score System

```gdscript
@export var score: int = 100:
    set(value):
        score = value
        EventBus.emit_signal("ui_update_score", value)
```

Score integration:
- Modified by bonus events (double_points multiplies by 2)
- Displayed in real-time via EventBus signal
- Persists across wave transitions

### Movement Configuration

```gdscript
@export var default_speed: float = 5.0
@export var player_control: float = 1.0    # Acceleration/deceleration base
@export var GRAVITY_MULT: float = 1.0
@export var can_jump: bool = true

@export var control_multiplayers: Dictionary = {
    "DEFAULT": 1.0,
    "CONCRETE": 1.0,
    "DIRT": 0.9,
    "MUD": 0.6,
    "ICE": 0.3,
}

@export var weight: float = 80             # For rigid body push calculations
```

Surface friction:
- Mud and ice reduce ground control significantly
- Applied via footstep module material detection
- Modified per-frame in `update_accel(material)`

### Camera System

```gdscript
@export var standart_fov: float = 75
@export var weapon_fov: float = 75

@export var mouse_speed: float = 0.01:     # Radians per pixel
    set(value):
        mouse_speed = value
        EventBus.emit_signal("mouse_speed_changed", value)

@export var bob_enabled: bool = true
@export_range(-0.5, 0.5) var bob_range: float = 0.03
@export_range(1, 5) var bob_freq: float = 2.3

@export var camera_bob_enabled: bool = true
@export_range(-0.5, 0.5) var bob_range_cam: float = 0.06
@export_range(1, 5) var bob_freq_cam: float = 2.3

@export var aim_bob_factor: float = 1.0   # Reduces bob while aiming (e.g., 0.5x)
```

Dual camera setup:
- Main camera (camera_3d) - world view
- Weapon camera (weapon_camera_3d) - first-person weapon via SubViewport
- Separate FOV for each to allow weapon zoom independent of world zoom

### Camera Bobbing

Bobbing applied based on movement speed:
- Weapon and camera bob at different frequencies
- Bob range increases when running
- Bob reduced by aim_bob_factor when aiming
- Horizontal and vertical components calculated separately

### Stairs Stepping

```gdscript
@export var step_enabled: bool = true
@export var step_max_slope: float = 0.35   # Radians
@export var step_max_height: float = 0.3   # Units
@export var step_min_height: float = 0.1   # Units
@export var ray_distant: float = 0.5       # Look-ahead distance
```

Automatic stair climbing:
- Raycast checks ahead for stairs
- If slope within threshold and height in range, applies upward velocity
- Prevents player from getting stuck on stairs
- Can be disabled per-level

### Bonus Integration

Player responds to bonus activations:

| Bonus | Effect |
|---|---|
| `quick_revive` | Auto-revive in 5s when laying down |
| `juggernog` | max_health *= 1.25 |
| `speed_cola` | default_speed *= 1.2 |

### Status Modifiers

Applied via StatusManager for dynamic adjustments:

| Modifier | Purpose |
|---|---|
| `speed_mult` | Percentage of speed to apply (1.0 = 100%) |
| `recoil_mult` | Camera recoil intensity |
| `spread_mult` | Weapon spread multiplier |
| `camera_shake_modifier` | Random camera shake strength |

Available methods:
- `get_hit(damage, normal)` - take damage, trigger laying_down if health <= 0
- `update_gravity(delta)` - apply gravity acceleration
- `update_input(speed, accel, decel)` - read input and calculate direction
- `update_velocity()` - apply move_and_slide with physics
- `camera_jump_animation()` - tween camera rotation for jump feedback
- `weapon_and_camera_bobbing(delta)` - calculate bob offsets
- `stairs_handler()` - automatic stair stepping
- `get_player_bottom()` - get world-space position of feet
- `_update_camera(delta)` - apply mouse rotation and camera shake

**PlayerMovementState** (base class)

Abstract base class for all movement states. Extends State (from state machine framework).

```gdscript
extends State
class_name PlayerMovementState

var PLAYER: Player
var ANIMATION: AnimationPlayer
var FOOTSTEPS: AudioStreamPlayer3D

func _ready() -> void:
    await owner.ready
    PLAYER = owner as Player
    ANIMATION = PLAYER.animation_player
    FOOTSTEPS = PLAYER.footsteps_module

func can_run() -> bool:
    return Input.is_action_pressed("sprint") \
        and PLAYER.stamina_component.is_stamina_zero() \
        and PLAYER.is_on_floor() \
        and not Global.weapon_manager.is_aiming
```

Common utilities:
- `PLAYER` - reference to main player controller
- `ANIMATION` - animation player for state animations
- `FOOTSTEPS` - footstep audio manager
- `can_run()` - check sprint prerequisites

## Movement States

**IdlePlayerState**

No movement, standing still. Entry point for most state transitions.

```gdscript
@export var SPEED: float = 5.0
@export var acceleration: float = 0.1
@export var deceleration: float = 0.05
```

Transitions:
- → FallingPlayerState: velocity.y < 0
- → JumpingPlayerState: jump input + on floor
- → CrouchingPlayerState: crouch input + on floor
- → WalkingPlayerState: velocity > 0.1

**WalkingPlayerState**

Normal movement at base speed.

```gdscript
@export var SPEED: float = 4.5          # Slower than idle for feel
@export var acceleration: float = 0.1
@export var deceleration: float = 0.05
```

Transitions:
- → FallingPlayerState: velocity.y < 0
- → JumpingPlayerState: jump input + on floor
- → RunningPlayerState: sprint input + stamina + not aiming
- → IdlePlayerState: velocity < 0.1
- → CrouchingPlayerState: crouch input + on floor

**RunningPlayerState**

Sprint state with stamina drain. Speed increased to 6.0.

```gdscript
@export var SPEED: float = 6.0
@export var acceleration: float = 0.1
@export var deceleration: float = 0.02         # Slower deceleration
@export var stamina_drain: float = 1.0         # per second
```

Logic:
- Requires sprint input AND non-zero stamina
- Drains stamina each frame via `stamina_component.try_use()`
- Transitions to walking if any condition fails
- Faster fall velocity (deceleration: 0.02)

Transitions:
- → FallingPlayerState: velocity.y < 0
- → JumpingPlayerState: jump input + on floor
- → WalkingPlayerState: sprint ends or stamina depleted
- → CrouchingPlayerState: crouch input + on floor

**CrouchingPlayerState**

Reduced player height and speed (2.5 m/s).

```gdscript
@export var SPEED: float = 2.5
@export var acceleration: float = 0.1
@export var deceleration: float = 0.05
@export_range(1, 6, 0.1) var CROUCH_SPEED: float = 4.0  # Animation speed
```

Features:
- Plays crouch animation forward at CROUCH_SPEED (2x-6x playback)
- Ceiling ShapeCast prevents uncrouch if blocked (loops until clear)
- Sound effects: CROUCH_IN on enter, CROUCH_OUT on exit
- Jump input while crouched triggers uncrouch (no jump)

Transitions:
- → IdlePlayerState: crouch input released and ceiling clear
- → (Blocked): Waits 0.1s if ceiling colliding, tries again

**JumpingPlayerState**

Upward velocity and air control.

```gdscript
@export var SPEED: float = 6.0
@export var acceleration: float = 0.02
@export var deceleration: float = 0.02
@export var stamina_drain: float = 1.5

@export var JUMP_VELOCITY: float = 4.5
@export_range(1, 2, 0.1) var INPUT_MULTIPLIER: float = 1.5
```

Jump mechanics:
- Requires stamina >= stamina_drain (1.5 units)
- Applies `velocity.y += JUMP_VELOCITY` (upward)
- Direction multiplied by INPUT_MULTIPLIER (1.5x) for momentum
- Plays jump animation and footstep sound
- Horizontal speed capped at 6.0 during jump

Transitions:
- → FallingPlayerState: velocity.y < 0
- → IdlePlayerState: is_on_floor() (both jump and fall land here)

**FallingPlayerState**

Gravity-only descent with fall damage on landing.

```gdscript
@export var SPEED: float = 6.0
@export var acceleration: float = 0.02
@export var deceleration: float = 0.02

@export var min_speed_damage: float = 8.0
@export var fall_damage_curve: Curve
@export var fatal_damage_speed: float = 30
```

Fall damage calculation:
```gdscript
# Only if fall_speed > min_speed_damage (8.0)
final_damage = (fall_damage_curve.sample(fall_speed / fatal_damage_speed) * max_health) + 1

# Example: falling at 10 m/s with 100 health
# Curve sample at 10/30 = 0.33 → ~33% of max health
```

Transitions:
- → IdlePlayerState: is_on_floor()
  - If fall_speed > 8.0: apply damage and play sound

**LyingDownPlayerState**

Incapacitated state after health reaches 0 while standing.

```gdscript
@export_range(50, 200, 1.0) var PLAYER_HEALTH: float = 200.0  # Laying health pool
@export_range(1, 6, 0.1) var LAY_SPEED: float = 4.0            # Animation speed

var revive_timer: float = 0.0
```

Mechanics:
- Animation plays "lay_down" at LAY_SPEED
- Player health set to PLAYER_HEALTH (200, twice the normal pool)
- Health decreases by 1 per second (bleed-out timer)
- If quick_revive active: auto-revive in 5 seconds

Revive logic:
```gdscript
if not InputSettings.is_multiplayer and PLAYER.quick_revive_active:
    revive_timer += delta
    if revive_timer > PLAYER.time_to_revive / 2:  # 5 seconds
        EventBus.player_revived.emit()
        transition.emit("idle_player_state")
```

On exit:
- health = player_default_health / 2 (half health restored)
- max_health restored to normal

Transitions:
- → IdlePlayerState: revive (quick_revive bonus or multiplayer revive)
- → (Blocked): health reaches 0 → player dies

**UiPlayerState**

Special state when UI is open. Locks input and mouse.

```gdscript
var previous_state: State

func enter(_previous_state: State) -> void:
    previous_state = _previous_state
    PLAYER.velocity = Vector3.ZERO
    PLAYER.can_move = false
    MouseManager.lock(&"ui_state")

func exit(_next_state: State) -> void:
    PLAYER.can_move = true
    MouseManager.unlock(&"ui_state")
```

Behavior:
- Stores previous state to return to when UI closes
- Freezes player movement (velocity reset)
- Locks mouse cursor
- Prevents any player input

Transitions:
- → previous_state: UI closes (EventBus.ui_player_state emitted false)
- → idle_player_state: fallback if previous_state unavailable

## Physics System

**Gravity**

```gdscript
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity"):
    get:
        return gravity * GRAVITY_MULT
```

Applied each frame via `update_gravity(delta)`:
```gdscript
velocity.y -= gravity * delta
```

Allows override via GRAVITY_MULT property.

**Input & Direction**

```gdscript
var raw_input: Vector2
var input_dir: Vector2
var direction: Vector3         # Smoothed movement direction
var wanted_direction: Vector3  # Target direction from input

func update_input(SPEED, acceleration, deceleration):
    raw_input = Input.get_vector(key_move_left, key_move_right, ...)
    # Also reads joypad axis if length_squared > 0.09
    
    input_dir = raw_input.limit_length(1.0)
    
    SPEED *= status_manager.get_modifier(&"speed_mult")
    wanted_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    # Smooth direction change with acceleration/deceleration
    direction = lerp(direction, wanted_direction, 
                     player_control * acceleration * current_control_multiplayer)
    
    # Apply to velocity
    if direction.length_squared() > 0.001:
        velocity.x = direction.x * SPEED
        velocity.z = direction.z * SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, deceleration)
        velocity.z = move_toward(velocity.z, 0, deceleration)
```

Surface friction applied to acceleration:
```gdscript
# Modified by current_control_multiplayer (default 0.9 for dirt, 0.6 for mud)
direction = lerp(direction, wanted_direction, 
                 player_control * acceleration * current_control_multiplayer)
```

**Rigid Body Physics**

Player pushes rigid bodies when colliding:

```gdscript
func _push_away_rigid_bodies() -> void:
    for collision in get_slide_collisions():
        if collision.get_collider() is RigidBody3D:
            var push_dir = -collision.get_normal()
            var mass_ratio = min(1.0, weight / collider.mass)
            
            if mass_ratio < 0.25:  # Too light to push
                continue
            
            push_dir.y = 0  # Horizontal only
            var push_force = mass_ratio * 5.0
            collider.apply_impulse(push_dir * velocity_diff * push_force, ...)
```

Prevents clipping through barrels, boxes, etc.

**Stair Stepping**

Automatic climbing over small obstacles:
```
func stairs_handler() -> void:
	if not step_enabled:
		return

	var step_input := Vector2(
		sign(raw_input.x) if abs(raw_input.x) > 0.1 else 0.0,
		sign(raw_input.y) if abs(raw_input.y) > 0.1 else 0.0
	)

	var half_height: float = collision_shape_3d.shape.height / 2.0
	stair_check.position = Vector3(
		step_input.x * ray_distant,
		step_max_height - half_height,
		step_input.y * ray_distant
	)
	stair_check.target_position.y = -step_max_height

	if not stair_check.is_colliding():
		return

	var surface_angle: float = acos(stair_check.get_collision_normal().dot(Vector3.UP))
	var step_height: float = abs(stair_check.get_collision_point().y - get_player_bottom())

	var can_step: bool = surface_angle <= deg_to_rad(step_max_slope) \
		and direction.length() > 0.1 \
		and is_on_floor() \
		and step_height > step_min_height \
		and step_height < step_max_height

	if can_step:
		velocity.y = current_speed * step_height * 1.25
		apply_floor_snap()
```

## Input System

All input configurable via InputMap (bindable in settings):

| Action | Purpose |
|---|---|
| `move_forward` | W key by default |
| `move_backward` | S key by default |
| `move_left` | A key by default |
| `move_right` | D key by default |
| `sprint` | Shift key by default |
| `jump` | Space key by default |
| `crouch` | Ctrl key by default |
| `reload` | R key by default |
| `interact_button` | E key by default |
| `flashlight` | F key by default |
| `inspect` | I key by default |
| `change_fire_mode` | Mouse middle by default |
| `pause` | Esc key by default |

## Integration Points

**EventBus Signals (Emitted)**

- `ui_update_score(score)` - score changed
- `player_changed_health(new_health, old_health)` - health modified
- `player_laying_down` - transitioned to LyingDownPlayerState
- `player_die` - health <= 0 while laying down
- `player_revived` - revived via quick_revive bonus
- `player_stamina_changed(stamina)` - stamina updated
- `player_stamina_changed_remaped(stamina)` - remaped to 0-1
- `mouse_speed_changed(value)` - mouse sensitivity changed
- `add_score(line, amount)` - request score addition
- `weapon_hitted(color)` - hit feedback to HUD
- `melee_attack` - melee was triggered

**EventBus Signals (Listened)**

- `bonus_activated(bonus_id, stacks)` - apply bonus effects
- `bonus_deactivated(bonus_id)` - remove bonus effects
- `update_settings` - reload FOV and graphics settings
- `ui_player_state(value)` - enter/exit UiPlayerState
- `melee_attack` - melee triggered

**Global Autoloads**

- `Global.player` - player instance reference
- `Global.players` - array of all player instances
- `Global.weapon_manager` - access to current weapon
- `Global.bonus_controller` - check active bonuses
- `GraphicsSettings` - camera FOV and rendering settings
- `InputSettings` - mouse sensitivity, joystick vibration

## Dependencies

- `StateMachine` - state management framework
- `StaminaComponent` - stamina pool and drain system
- `StatusManager` - status modifiers and buffs
- `AnimationPlayer` - animations for states
- `FootStepsModule` - footstep sounds
- `WeaponManager` - current weapon and aiming state
- `EventBus` - inter-system messaging (autoload)
- `Global` - global state container (autoload)
- `InputSettings` - input configuration (autoload)
- `GraphicsSettings` - graphics configuration (autoload)

## Performance Considerations

- **Physics process** - called each physics frame (60 FPS)
  - Gravity, input, movement calculations
  - Collision handling and rigid body pushing
  - Stair stepping raycast
  - Camera update (mouse input, rotation)
  - Bob calculation

- **Animation** - state transitions trigger animation playback
  - Only play on state enter, not continuously
  - Reuse animation player across states

- **Health healing** - only active when not at max health
  - Lazy calculation using remap + curve
  - 5 second delay before healing starts

## Best Practices

1. **Use state machine for movement** - cleaner than nested conditionals
2. **Apply modifiers through StatusManager** - centralized buff tracking (not used in this case yet)
3. **Use EventBus for score/damage** - decouples systems
4. **Clamp camera rotation** - prevent gimbal lock issues
5. **Store surface friction** - don't recalculate every frame
6. **Debounce input** - use `just_pressed` for discrete actions
7. **Test fall damage curve** - tune to prevent insta-death
8. **Test stairs on slopes** - verify raycast doesn't trigger false positives
9. **Profile physics callbacks** - rigid body pushing can be expensive
10. **Layer camera correctly** - weapon and world cameras on different layers

## Configuration Guide

**Adjusting Movement Feel**

- `default_speed` - base walking speed (5.0 m/s)
- `player_control` - acceleration responsiveness (1.0 = immediate)
- `GRAVITY_MULT` - gravity strength (1.0 = default)
- `bob_range` - weapon bob amplitude (±0.03 by default)
- `bob_freq` - bob oscillation frequency (2.3 Hz)

**Adjusting Combat**

- `max_health` - starting health (100 units)
- `heal_per_second` - regeneration rate (3 per second after 5s delay)
- `stamina_component.max_stamina` - sprint duration
- `weight` - how much rigid bodies player can push

**Adjusting Jumping**

- `can_jump` - enable/disable jumping
- `JumpingPlayerState.JUMP_VELOCITY` - jump height (4.5 upward)
- `JumpingPlayerState.stamina_drain` - stamina cost (1.5)

**Adjusting Stairs**

- `step_enabled` - enable/disable auto-stepping
- `step_max_slope` - maximum climbable angle (0.35 rad ≈ 20°)
- `step_max_height` - tallest step to climb (0.3 units)
- `step_min_height` - smallest step to climb (0.1 units)
