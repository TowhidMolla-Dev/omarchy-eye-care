# omarchy-eye-care

An Omarchy shell plugin that helps you follow the **20-20-20 rule** against eye strain.

- 20 minutes of work → 20 seconds of rest → repeat (fixed values)
- Fullscreen countdown + desktop notification on every break
- Remaining time shown in the bar

## What is the 20-20-20 rule?

> Every 20 minutes, look at something 20 feet away for 20 seconds.

Eye strain comes from the focusing muscles (mainly the ciliary muscle) getting tired
from continuous near work. Looking far away at regular intervals lets them rest,
which prevents fatigue.

Reference (in Japanese): [眼精疲労対策（20-20-20ルール）| 古川中央眼科](https://www.eye-care.or.jp/sittoku/%E7%9C%BC%E7%B2%BE%E7%96%B2%E5%8A%B4%E5%AF%BE%E7%AD%96%EF%BC%8820-20-20%E3%83%AB%E3%83%BC%E3%83%AB%EF%BC%89/)

The break messages also borrow from the American Academy of Ophthalmology's
recommendations for screen users:

1. Blink consciously while working
2. Keep the screen at arm's length (50-60 cm) and below eye level

## Usage

### Enable / disable (persistent across restarts)

```bash
omarchy plugin disable usutani.eye-care
omarchy plugin enable usutani.eye-care --section right
omarchy plugin list
```

Also available from the menu: `Setup > Plugins > Enable / Disable`.

### Pause / resume / skip (without disabling the plugin)

- Left-click the `󰈈 14:32` label in the bar: pause / resume
- Right-click the label: skip the current phase (work → break now, break → back to work)
- Same via IPC: `omarchy-shell eye-care toggle` / `stop` / `start` / `skip` / `status`

### About the break overlay

The 20-second countdown can be dismissed (click outside the card, Esc, or the
"Back to work" button). Dismissing it starts the next work phase.

## Development

```bash
# Validate before publishing (required)
omarchy plugin validate ~/Work/omarchy-eye-care

# Manual install (while developing)
mkdir -p ~/.config/omarchy/plugins/usutani.eye-care
cp ~/Work/omarchy-eye-care/{manifest.json,Service.qml,BarWidget.qml,Overlay.qml} ~/.config/omarchy/plugins/usutani.eye-care/
omarchy-shell shell rescanPlugins
omarchy plugin enable usutani.eye-care --section right
```

To verify the break behavior without waiting 20 minutes:

1. Open the live copy at `~/.config/omarchy/plugins/usutani.eye-care/Service.qml` and
   temporarily shrink `workSeconds` / `restSeconds` (e.g. 60 / 10).
   Service code is only reloaded on a shell restart (service instances are kept
   across `rescanPlugins`), so run `omarchy restart shell` afterwards.
   The screen flickers briefly while the shell restarts.
2. Check two full cycles against this list:
   - [ ] The "Rest your eyes" notification appears when work time runs out
   - [ ] The fullscreen countdown overlay opens
   - [ ] The overlay closes at zero with the "Break over" notification
   - [ ] The bar label returns to the work countdown
   - [ ] The overlay can be dismissed (outside click, Esc, "Back to work")
3. When done, restore the production values (1200 / 20) and run
   `omarchy restart shell` again to pick them up.
4. Make sure the repo copy at `~/Work/omarchy-eye-care/Service.qml` still holds
   the production values (do not leak the temporary change back into the repo).

## File layout

| File | Role |
| --- | --- |
| `manifest.json` | Plugin definition (`service` + `bar-widget` + `overlay`) |
| `Service.qml` | Timer core (single source of truth). A 1-second `Timer` alternates `work` ⇄ `rest` |
| `BarWidget.qml` | Bar countdown. Read-only view via `shell.serviceFor()` plus quick controls |
| `Overlay.qml` | Fullscreen 20-second countdown (`PanelWindow`, `WlrLayer.Overlay`) |

## License

MIT
