# GConsole

An in-game developer console for Godot 4. Press **`~`** to open it.

Built to be dropped into any project — nothing in here knows about a particular
game.

## Install

Copy this folder into your project as `addons/gconsole`, then enable
**GConsole** in *Project → Project Settings → Plugins*.

Enabling it does three things:

1. registers the `GConsole` autoload
2. adds every setting under the **GConsole** category in Project Settings
3. writes `res://gconsole.cfg` in your project root

That `.cfg` sits in *your* repo, not the addon's, because the values describe
your game rather than the plugin. Commit it and everyone gets the same console
setup from a checkout. It is never overwritten once it exists.

## Using it

```gdscript
func _ready() -> void:
    GConsole.add_command("heal", _heal, [], 0, "Refill player health")
    GConsole.add_command("give", _give, ["item", "count"], 1, "Give an item")
    GConsole.add_command_autocomplete_list("give", PackedStringArray(["sword", "potion"]))

    GConsole.add_cvar("god_mode", false, "Ignore all damage", true)

func _heal() -> void:
    GConsole.print_success("healed")
```

### Output

| Call | Use |
|---|---|
| `print_line` | plain output |
| `print_command` | echoes a command, terminal style |
| `print_info` / `print_warning` / `print_error` | the usual three |
| `print_success` | confirmations |
| `print_debug_line` | verbose detail |

Colours come from `GConsoleTheme`, so callers ask for a *meaning* and never a
`Color`. Retheming touches one place.

### Keys

| Key | Does |
|---|---|
| `~` | toggle |
| `Ctrl` + `~` | toggle full screen |
| `Tab` | cycle the suggestion under the cursor |
| `↑` / `↓` | walk command history |
| `Ctrl` + `C` | clear the input line |
| `PgUp` / `PgDn` | scroll output |
| `Ctrl` + wheel | font size |
| `Esc` | close |

## Settings

All under **GConsole** in Project Settings, grouped into `display`, `behaviour`
and `colors`. Defined once in `console/console_settings.gd` — the editor plugin
registers them from that list and the runtime reads them back from it, so the
two cannot drift apart.

Highlights: `display/theme` takes a `Theme` resource, `behaviour/scrollback_limit`
caps the output buffer, `behaviour/echo_commands` turns the terminal-style
transcript on or off, and `colors/suggestion` plus `colors/suggestion_selected`
control the autocomplete popup.

## Layout

```
gconsole/
├── plugin.cfg
└── console/
    ├── console.gd             autoload: UI, input, output
    ├── console_plugin.gd      editor plugin: autoload + settings
    ├── console_settings.gd    every tunable, defined once
    ├── console_theme.gd       semantic colours and Theme loading
    ├── console_autocomplete.gd
    ├── console_commands.gd
    ├── console_cvars.gd
    ├── console_executor.gd
    ├── console_history.gd
    ├── console_level_utils.gd
    └── system_color.gd        [system_color] bbcode effect
```

## Upgrading from 1.x

- the autoload is **`GConsole`**, was `Console`
- settings moved from `console/*` to `gconsole/display|behaviour|colors/*`
- `[system_color color=CONSOLE_COLOR_ERROR]` still works; `color=ERROR` is the
  shorter spelling now
