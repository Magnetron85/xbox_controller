# xbox_controller

Drive a radiology reading workstation (PACS + dictation) from a wired Xbox controller. Replaces mouse, keyboard hotkeys, and foot pedal for reading sessions. AutoHotkey v2.

Designed for InteleViewer + PowerScribe 360 but configurable for any PACS/dictation pair via JSON.

## Requirements

- Windows 10/11
- AutoHotkey v2.0+ (https://www.autohotkey.com/)
- Wired Xbox controller (tested with Xbox Series X|S Controller, Model 1914)

## Run

```
AutoHotkey64.exe main.ahk                    # live mode — sends real input
AutoHotkey64.exe main.ahk --simulate         # logs what would be sent; no real input
AutoHotkey64.exe main.ahk --profile colleague_name
```

A small HUD appears in the bottom-right corner of the primary monitor. Press **Ctrl+Shift+Esc** to exit.

The HUD has three modes (set via `hud_mode` in your profile preferences):

- `"fade"` (default) — hidden at rest; fades in briefly when an action fires, then fades out
- `"always"` — visible at fixed alpha
- `"off"` — never shown (file log still written)

Hold **left-stick click** to toggle the HUD off/on at runtime.

## Default button map

| Input | Tap | Hold |
|---|---|---|
| Right stick | Move cursor (variable speed) | — |
| Left stick ↑/↓ | Previous / next PowerScribe field | — |
| Left stick ←/→ | Hanging protocol back / forward | — |
| D-pad ↑/↓ | Previous / next series | — |
| D-pad ←/→ | Previous / next prior | — |
| LT (analog) | Scroll stack down (variable) | — |
| RT (analog) | Scroll stack up (variable) | — |
| A | Press = left-mouse down, release = up. Tap → click; two quick taps → double-click; hold while moving right stick → click-and-drag (e.g., measurements). | — |
| B | Right click | — |
| X | Measure | Arrow |
| Y | ROI | Text annotation |
| LB | Cycle windowing preset (F4→F5→F6→F7) | W/L drag (release to exit) |
| RB | Dictate on/off (toggle) | — |
| LS click | Toggle precision mouse mode | Toggle HUD visibility |
| RS click | Middle click | — |
| View (Back) | MPR cycle | Reset viewer (destructive — 500 ms hold with haptic warn) |
| Menu (Start) | Undo last annotation | Erase all (destructive — 500 ms hold with haptic warn) |

## Architecture

```
main.ahk
├── lib/json.ahk          minimal pure-AHK JSON parser
├── lib/xinput.ahk        XInput DllCall wrapper
├── lib/events.ahk        state-diff → tap/hold/double/stick events
├── lib/hud.ahk           overlay with fade/always/off modes
├── lib/haptics.ahk       named vibration patterns
├── lib/mouse.ahk         right-stick cursor + variable scroll
├── lib/dispatcher.ahk    action → target routing + WinActivate + send
└── lib/profile.ahk       profile + defaults loader, merge

profiles/
├── _defaults/
│   ├── targets.json      window-match rules for PACS, PowerScribe
│   ├── keymaps.json      action_id → target + keys + haptic
│   └── haptics.json      named vibration patterns
└── <name>.json           per-user bindings and preferences
```

The layers are independent:

- **Input layer** emits semantic events (`tap`, `hold`, `stick_l_dir`, etc.) from raw controller state.
- **Profile layer** maps events → action IDs (`series_prev`, `measure_toggle`).
- **Keymap layer** maps action IDs → target app + keystroke (`pacs` → `{PgUp}`).

Swapping PACS vendors is an edit to `keymaps.json` and `targets.json`, not a rewrite.

## Customization

To add a new radiologist profile, copy `profiles/mike.json` to `profiles/<yourname>.json` and edit the `bindings` and `preferences` sections. Launch with `--profile <yourname>`.

To adapt to a non-Intelerad PACS, edit `profiles/_defaults/targets.json` (window-match rules) and `profiles/_defaults/keymaps.json` (keystrokes for each action).

## Safety

- **No action is mapped to a single tap for destructive operations.** Reset viewer and erase all require a 500 ms hold with an escalating haptic warning.
- **No binding for signing reports.** Deliberately excluded.
- The `--simulate` flag logs keystrokes to the HUD instead of sending them — use this while tuning a profile.

## Development

AHK v2 is case-insensitive for identifiers, so class names and globals must not collide. Globals in `main.ahk` use the `g_` prefix.

To smoke-test changes without a controller, launch `--simulate` and watch the HUD for semantic events as you press buttons (once a controller is attached).

## License

MIT. See [LICENSE](LICENSE). Security policy in [SECURITY.md](SECURITY.md).
