# omarchy-eye-care

> **This is a fork of [`usutani/omarchy-eye-care`](https://github.com/usutani/omarchy-eye-care)
> (MIT, © 2026 usutani).** The only substantive change is that the countdown
> survives a shell restart. Install the original instead if you don't need that.
> See [What changed](#what-changed) below.

An Omarchy shell plugin that helps you follow the **20-20-20 rule** against eye strain.

- 20 minutes of work → 20 seconds of rest → repeat (fixed values)
- Fullscreen countdown + desktop notification on every break
- Remaining time shown in the bar
- The countdown survives `omarchy restart shell` and shell crashes

## Requirements

No external dependencies beyond the default Omarchy install.

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

### Bar display: full, ring, or hover

Two health timers on one bar is a lot of pixels, so the bar widget has three
display modes, chosen in the settings panel (left-click the widget) and saved
across restarts.

| Mode | Shows | Width |
|---|---|---|
| `Full` | Icon and countdown, as upstream | ~67px |
| `Ring` (default) | Icon inside a ring that fills as the 20 minutes run | ~29px |
| `Hover` | Icon until you hover it, then the countdown slides in | 29px → 67px |

`Ring` is the default because a countdown's value is that you can read it
*without* pointing at it. Hiding the number behind a hover would mean you have
to hover every single time you want to know, which is strictly worse than a
number that is always there — and with two such widgets, every sweep of the
pointer across the bar would reflow the layout twice. The ring answers "how
long until my break?" in a glance instead, and its colour turns urgent when
the timer is paused.

The full status is always on the tooltip, so `Ring` costs you nothing but
width. `Hover` is there for people who prefer the bar to stay visually quiet
until they ask for it.

You can also set the mode over IPC:

```bash
omarchy-shell eye-care mode ring     # full | compact | hover
```

### Enable / disable (persistent across restarts)

```bash
omarchy plugin disable towhid.eye-care
omarchy plugin enable towhid.eye-care --section right
omarchy plugin list
```

Also available from the menu: `Setup > Plugins > Enable / Disable`.

### Removal

```bash
omarchy plugin remove towhid.eye-care
```

### Pause / resume / skip (without disabling the plugin)

- Left-click the `󰈈 14:32` label in the bar: pause / resume
- Right-click the label: skip the current phase (work → break now, break → back to work)
- Same via IPC: `omarchy-shell eye-care toggle` / `stop` / `start` / `skip` / `status`

### About the break overlay

The 20-second countdown can be dismissed (click outside the card, Esc, or the
"Back to work" button). Dismissing it starts the next work phase.

## What changed

Everything here except `Service.qml`'s timer core is unchanged from upstream.

The original counted down with `remaining -= 1` from a property initializer, so
every shell start re-ran it and the 20-minute interval began again. This fork
stores an absolute wall-clock **deadline** instead and derives the display from
`Date.now()`, so a restart resumes where the countdown actually was. Deriving
rather than decrementing also removes per-tick drift.

The deadline is written to
`$XDG_STATE_HOME/omarchy/towhid.eye-care/timer.json`, and only when the work
phase is armed or paused — a few writes per 20-minute cycle, not one per second.

Behaviour at the edges:

- **Paused** before a restart → comes back still paused, at the same remaining time.
- **Deadline elapsed while the shell was down** (hours later, after a reboot) →
  starts a fresh 20-minute phase rather than firing a stale eye break at login.
- **A break interrupted by the restart** → not resumed; the 20-second rest is
  too short to be worth replaying.
- The `eye-care` IPC target is unchanged, so the documented
  `omarchy-shell eye-care ...` commands still work. Because that target is
  shared with upstream, do not run this fork and `usutani.eye-care` at the same
  time.

One implementation trap worth knowing if you extend this: the deadline property
must be declared `double`, not `int`. A millisecond epoch is around `1.79e12`
and silently overflows a 32-bit QML `int` (max `~2.1e9`), which makes every
restored countdown read as already expired.

## Development

```bash
# Validate before publishing (required)
omarchy plugin validate ~/Work/omarchy-eye-care

# Manual install (while developing)
mkdir -p ~/.config/omarchy/plugins/towhid.eye-care
cp ~/Work/omarchy-eye-care/{manifest.json,Service.qml,BarWidget.qml,Overlay.qml} ~/.config/omarchy/plugins/towhid.eye-care/
omarchy-shell shell rescanPlugins
omarchy plugin enable towhid.eye-care --section right
```

To verify the break behavior without waiting 20 minutes:

1. Open the live copy at `~/.config/omarchy/plugins/towhid.eye-care/Service.qml` and
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

MIT — see [LICENSE](LICENSE), which retains the original © 2026 usutani copyright.
