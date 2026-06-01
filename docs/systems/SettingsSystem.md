# Settings System

A modular, tab-based settings management system supporting graphics, display, audio, input, and miscellaneous configurations. Handles persistent storage, real-time application of settings, and cross-system integration.

## Architecture

Five specialized layers, each handling a distinct settings category:

```
SettingsMain            - tab container, UI orchestration, locale management
SettingsDisplay         - display mode, monitor selection, framerate, scaling, vsync
SettingsGraphics        - rendering quality presets, visual effects toggles
SettingsSounds          - audio bus volume controls (master, weapon, SFX, music)
SettingsInput           - keybinding remapping, mouse sensitivity, controller vibration
SettingsOther           - language selection, performance toggles (weapon preloading)
SettingsUtils           - device detection, screen metrics calculation
```

## Components

**SettingsMain** (`settings_main.gd`)

Central controller managing the settings UI TabContainer and cross-tab state. Serves as a signal hub for locale loading.

```gdscript
extends Control
class_name SettingsMain

signal locale_loaded      # Emitted when localization is ready
signal close_requested    # Emitted when settings tab (0) is selected
```

Features:
- Tracks runs count (`runs_count`) to distinguish first-time setup
- Auto-selects Display tab (1) on visibility
- Manages tab titles with localization keys
- Delays locale_loaded signal by 2.5s to ensure all translations load

Available methods:
- `init_tabs_tittles()` - apply localized tab titles
- `handle_tab_select(idx)` - emit close_requested when settings tab (0) is selected
- `alert(title, text)` - show native OS alert dialog

**SettingsDisplay** (`settings_display.gd`)

Manages display and window settings: mode, monitor, framerate cap, UI scaling, and vsync.

```gdscript
enum DisplayMode { 
    FULLSCREEN,              # 0
    EXCLUSIVE_FULLSCREEN,    # 1
    WINDOWED                 # 2
}

@export var default_config: Dictionary = {
    'display': {
        'display_mode': 0,
        'display_monitor': DisplayServer.get_primary_screen(),
        'custom_framecap': 0,          # 0 = unlimited, >0 = cap
        'interface_scaling': 1.0,      # Auto-calculated from DPI
        'vsync': true,
    },
}
```

UI elements mapping:

| Setting | Element Type | Key | Description |
|---|---|---|---|
| `display_mode` | OptionButton | `&'display_mode'` | Fullscreen / Windowed |
| `display_monitor` | OptionButton | `&'display_monitor'` | Monitor selection |
| `frame_cap` | HSlider | `&'frame_cap'` | Framerate limit (0-240 FPS) |
| `interface_scaling` | HSlider | `&'interface_scaling'` | UI scale factor (1.0-3.0) |
| `vsync` | CheckButton | `&'vsync'` | Vertical sync toggle |

Available methods:
- `init_signals()` - connect UI elements to handlers
- `init_option_buttons()` - populate OptionButton choices
- `restore_settings_from_config()` - load saved values
- `update_label(value)` - refresh label text with current value

**SettingsGraphics** (`settings_graphics.gd`)

Manages graphics quality presets and visual effect toggles. Synchronizes UI with `GraphicsSettings` and `GraphicsPreset` resources.

Graphics presets (resource-based):
- Low, Medium, High, Ultra (configurable in `graphics_presets` array)
- Custom (dynamically generated when user overrides preset settings)

UI elements (50+ settings):

| Category | Elements | Keys |
|---|---|---|
| **Presets** | Option | `graphics_preset` |
| **Upscaling** | Option, Slider | `scaling_method`, `render_resolution`, `fsr_sharpness` |
| **Ambient Occlusion** | Option | `ssao_preset` |
| **Anti-Aliasing** | Options | `msaa_preset`, `fxaa`, `taa` |
| **Shadows** | Option, Check | `shadow_quality`, `shadows` |
| **Shaders** | Option, Check | `shaders_quality` |
| **Lighting** | Checks | `glow`, `sdfgi`, `ssil`, `volumetric_fog` |
| **Reflections** | Checks | `ssr` |
| **Camera** | Sliders | `main_camera_fov`, `weapon_camera_fov` |
| **Environment** | Checks | `vegetation`, `water_puddles`, `vfx` |
| **Advanced** | Check | `single_layer_render` |

All settings stored in `ui_elements` Dictionary for dynamic management:
```gdscript
@onready var ui_elements: Dictionary[StringName, Dictionary] = {
    &'setting_key': {
        &'label': Label node reference,
        &'option_button': OptionButton reference (if applicable),
        &'slider': HSlider reference (if applicable),
        &'check_button': CheckButton reference (if applicable),
        &'container': HBoxContainer reference,
    }
}
```

Key features:
- Delayed signal ignoring (0.5s) to prevent feedback loops
- Preset matching when individual settings change
- Automatic fallback to "Custom" preset if no matching preset found
- Integration with `GraphicsSettings` autoload for real-time effect

Available methods:
- `init_option_buttons()` - populate graphics preset dropdown
- `init_signals()` - connect all UI elements to handlers
- `restore_settings_from_config(preset)` - apply preset to UI
- `on_setting_changed()` - handle individual setting changes
- `get_current_settings()` - read all settings from UI
- `find_matching_preset(settings)` - match current settings to preset index
- `apply_and_select_preset(preset)` - apply preset and update UI

**SettingsSounds** (`settings_sounds.gd`)

Manages audio bus volumes with real-time feedback.

```gdscript
enum AUDIO_BUS { 
    MASTER,    # 0
    WEAPON,    # 1
    MUSIC,     # 2
    SFX        # 3
}

@export var default_cfg: Dictionary = {
    'audio': {
        'master_volume': 1.0,
        'weapon_volume': 1.0,
        'sfx_volume': 1.0,
        'music_volume': 1.0,
    },
}
```

UI elements:

| Bus | Label | Slider |
|---|---|---|
| Master | `master_label` | `master_volume_slider` |
| Weapon | `weapon_label` | `weapon_volume_slider` |
| Music | `music_label` | `music_volume_slider` |
| SFX | `sfx_label` | `sfx_volume_slider` |

Available methods:
- `_init_signals()` - connect sliders to volume update handler
- `_load_from_settings()` - restore saved volumes from config
- `update_volume_and_text(value, label, text, bus)` - set bus volume and update label
- `get_volume_from_data(key)` - extract volume value from config data

**SettingsInput** (`settings_input.gd`)

Manages keybinding remapping and controller settings with multi-device support.

```gdscript
@export var input_actions: Dictionary = {
    "move_forward": "KEY_SETTINGS_MOVE_FORWARD",
    "move_left": "KEY_SETTINGS_MOVE_LEFT",
    "move_backward": "KEY_SETTINGS_MOVE_BACKWARD",
    "move_right": "KEY_SETTINGS_MOVE_RIGHT",
    "jump": "KEY_SETTINGS_MOVE_JUMP",
    "crouch": "KEY_SETTINGS_MOVE_CROUCH",
    "sprint": "KEY_SETTINGS_SPRINT",
    "melee_attack": "KEY_SETTINGS_MELEE_ATTACK",
    "reload": "KEY_SETTINGS_RELOAD",
    "interact_button": "KEY_SETTINGS_INTERACT_BUTTON",
    "flashlight": "KEY_SETTINGS_FLASHLIGHT",
    "inspect": "KEY_SETTINGS_INSPECT",
    "change_fire_mode": "KEY_SETTINGS_FIRE_MODE",
    "pause": "KEY_SETTINGS_PAUSE",
    # ...system actions...
}

enum JoypadType { XBOX, PLAYSTATION, NINTENDO, GENERIC }
```

Input remapping display:
- Dynamically creates `InputRemapButton` instances for each action
- Shows current binding (keyboard or gamepad icon)
- Supports multiple input devices simultaneously
- Detects joypad connection/disconnection and updates UI

UI elements:
- `action_list` (VBoxContainer) - container for remap buttons
- `mouse_sensitivity_slider` - mouse look speed (0.0-1.0+)
- `joy_vibration_button` - rumble toggle (CheckButton)
- `reset_actions_bt` - reset to defaults (Button)

Available methods:
- `init_keymapping()` - setup remapping system
- `handle_joy_vibration()` - connect vibration toggle
- `handle_mouse_sensitivity()` - connect mouse sensitivity slider
- `_load_keybindings_from_settings()` - restore saved keybinds
- `_create_action_list()` - generate remap button UI
- `_update_action_remapping(action, event)` - change keybinding
- `reset_actions()` - restore default keybindings

**SettingsOther** (`settings_other.gd`)

Miscellaneous settings: language selection and performance options.

```gdscript
@export var locale_string_to_full_string: Dictionary[String, String] = {
    'en': 'English',
    'ru': 'Русский',
}
```

UI elements:
- `language_option_button` (OptionButton) - language selection
- `preload_weapon_button` (CheckButton) - weapon scene preloading toggle

Available methods:
- `init_languages()` - populate language dropdown from TranslationServer
- `restore_from_config()` - load saved language and options
- `preload_weapon(enabled)` - toggle weapon preloading
- `language_option_button_item_selected(index)` - change language and save

**SettingsUtils** (`settings_utils.gd`)

Utility functions for device detection and screen metrics.

Available methods:
- `is_mobile_device()` - check if running on mobile (using OS.has_feature)
- `get_screen_size_inches()` - calculate physical screen size via DPI

DPI-based scaling calculation:
```gdscript
var scaling_value: float = 1.0

if SettingsUtils.is_mobile_device():
    scaling_value = float(DisplayServer.screen_get_dpi()) / 216.0
else:
    var diagonal_inches = SettingsUtils.get_screen_size_inches()
    scaling_value = float(DisplayServer.screen_get_dpi()) / (diagonal_inches * 2)
    scaling_value = min(3.0, scaling_value)  # Cap at 3x
```

## Configuration Storage

Settings persist via `ConfigFileHandler` autoload:

Structure:
```gdscript
{
    'core': {
        'preload_weapons_scenes': bool
    },
    'display': {
        'display_mode': int,
        'display_monitor': int,
        'custom_framecap': float,
        'interface_scaling': float,
        'vsync': bool,
    },
    'graphics': {
        'graphics_preset': int,
        'scaling_method': int,
        'render_resolution': float,
        'fsr_sharpness': float,
        'ssao_preset': int,
        'msaa_preset': int,
        'shadow_quality': int,
        # ... 30+ more graphics settings ...
    },
    'audio': {
        'master_volume': float,     # 0.0-1.0+
        'weapon_volume': float,
        'sfx_volume': float,
        'music_volume': float,
    },
    'input': {
        'mouse_sensitivity': float,  # typically 0.002
        'joy_vibration': bool,
        # ... keybinding mappings ...
    },
    'other': {
        'language': String,          # 'en', 'ru', etc.
    }
}
```

## Integration Points

**EventBus Signals**

- `EventBus.update_settings.emit()` - broadcast when graphics or gameplay settings change

**Global Autoloads**

- `GraphicsSettings` - real-time graphics state (read by rendering systems)
- `InputSettings` - input configuration (mouse sensitivity, vibration)
- `ConfigFileHandler` - persistent storage backend
- `DelayedSaverManager` - debounce config writes to avoid disk thrashing

**Real-time Application**

Graphics settings apply immediately:
```gdscript
# DisplayServer changes
DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
DisplayServer.window_set_current_screen(monitor_index)

# Audio buses
AudioServer.set_bus_volume_db(bus_index, db_level)

# Input configuration
InputSettings.mouse_sens = value
InputSettings.joy_vibration = value
```

## Adding New Settings

Complete workflow for adding a new setting:

### 1. Add UI Element to Settings Scene

In the settings control scene (.tscn):
- Create a container (HBoxContainer)
- Add a Label with the setting name
- Add appropriate control (CheckButton, HSlider, OptionButton)
- Name the control with a unique identifier (e.g., `%my_setting_button`)

### 2. Update Settings Script

In the appropriate settings script (e.g., `settings_graphics.gd`):

```gdscript
@onready var ui_elements: Dictionary[StringName, Dictionary] = {
    # ...existing settings...
    &'my_setting': {
        &'label': %my_setting_label,
        &'check_button': %my_setting_button,
        &'container': %my_setting_container,
    }
}
```

### 3. Add Signal Connection

In `init_signals()`:

```gdscript
func init_signals() -> void:
    # ...existing connections...
    
    ui_elements[&'my_setting'][&'check_button'].toggled.connect(
        func(value: bool):
            config_file_handler.config_save({ 'graphics': { 'my_setting': value } })
            EventBus.update_settings.emit()
    )
```

### 4. Add to Global Settings Storage

Update `GraphicsSettings` autoload:
```gdscript
# graphics_settings.gd
var my_setting: bool = true  # default value
```

### 5. Add to GraphicsPreset Resource

Update `GraphicsPreset` resource (.tres):
- Add property with same name and type
- Include in `serialize()` method

```gdscript
# graphics_preset.gd
@export var my_setting: bool = true

func serialize() -> Dictionary:
    return {
        # ...existing fields...
        'my_setting': my_setting,
    }
```

### 6. Restore on Launch

In settings script `_ready()` or `restore_settings_from_config()`:

```gdscript
var loaded_graphics = config_file_handler.config_load_filtered(
    { 'graphics': { 'my_setting': true } }  # default fallback
)
ui_elements[&'my_setting'][&'check_button'].button_pressed = loaded_graphics['graphics']['my_setting']
```

## Localization Integration

All user-visible text uses localization keys:

```gdscript
# In scripts
tr("KEY_SETTINGS_DISPLAY")  # Retrieves translated string

# Tab titles
tab_container.set_tab_title(1, "KEY_SETTINGS_DISPLAY")

# In signal handlers
label.text = tr(&'KEY_SETTING_FRAMECAP') % [value]  # Format with value
```

Localization files loaded from `res://localization/` (managed by `TranslationServer`).

## Usage Example

```gdscript
# Check current setting
var is_fullscreen = GraphicsSettings.display_mode == DisplayMode.FULLSCREEN

# Listen to setting changes
EventBus.update_settings.connect(func():
    print("Settings changed!")
)

# Load a graphics preset
var preset = graphics_presets[2]  # Load Ultra preset
settings_graphics.restore_settings_from_config(preset.serialize())

# Change volume programmatically
AudioServer.set_bus_volume_db(0, linear2db(0.5))  # 50% master volume
```

## Dependencies

- `ConfigFileHandler` - persistent storage backend
- `DelayedSaverManager` - debounced config writing
- `GraphicsSettings` - graphics state container (autoload)
- `InputSettings` - input state container (autoload)
- `EventBus` - inter-system messaging (autoload)
- `GraphicsPreset` - resource definition for graphics presets
- `TranslationServer` - built-in Godot localization
- `DisplayServer` - built-in Godot display API
- `AudioServer` - built-in Godot audio API
- `InputSettings` - custom input configuration storage

## Best Practices

1. **Use StringName for dictionary keys** - faster lookups (`&'setting_name'`)
2. **Store defaults in @export** - makes them easy to tweak
3. **Apply settings immediately** - don't queue or batch UI updates
4. **Debounce file writes** - use `DelayedSaverManager` for slider changes
5. **Provide sensible defaults** - fallback values in `config_load_filtered()`
6. **Group related settings** - organize in tabs by category
7. **Localize all UI text** - maintain translation keys for all strings
8. **Validate ranges** - clamp values (especially sliders) before applying
9. **Emit signals for systems** - use `EventBus.update_settings` not direct calls

## Performance Considerations

- **Lazy loading** - tabs only initialize when visible
- **Delayed saving** - 0.5s debounce on slider changes to reduce disk I/O
- **UI dictionary caching** - `ui_elements` dictionary built once at `_ready()`
- **Preset matching** - only triggered on setting change, not on every frame
- **DPI calculation** - computed once at startup, not per frame

## Troubleshooting

**Settings not persisting:**
- Check `ConfigFileHandler` is initialized before settings load
- Verify config file path is writable
- Check for exceptions in `config_file_handler.config_save()`

**UI not updating:**
- Ensure `ui_elements` dictionary has correct node references (use `%unique_names`)
- Check signal connections are firing (`print_debug()` in handlers)
- Verify label text includes localization key

**Graphics changes not visible:**
- Confirm `GraphicsSettings` autoload has corresponding property
- Check `EventBus.update_settings` is being emitted
- Verify rendering system listens to `update_settings` signal

**Input remapping not working:**
- Check `InputMap.get_actions()` includes all mapped actions
- Verify `input_actions` dictionary has correct action names
- Confirm `ConfigFileHandler` saves/loads keybind data correctly
