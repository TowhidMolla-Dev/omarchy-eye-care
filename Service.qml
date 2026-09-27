import QtQuick
import Quickshell
import Quickshell.Io

// Timer core for the 20-20-20 rule (single source of truth).
// 20 minutes of work → 20 seconds of rest → repeat. Fixed values.
// BarWidget / Overlay reference this instance via
// shell.serviceFor("usutani.eye-care") and display phase / remaining / paused.
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  readonly property string pluginId: "usutani.eye-care"

  // 20-20-20 rule: every 20 minutes, look at something
  // 20 feet away for 20 seconds.
  readonly property int workSeconds: 1200
  readonly property int restSeconds: 20

  // "work" | "rest"
  property string phase: "work"
  property int remaining: workSeconds
  property bool paused: false

  function formatTime(totalSeconds) {
    var s = Math.max(0, totalSeconds)
    var m = Math.floor(s / 60)
    var r = s % 60
    return m + ":" + (r < 10 ? "0" + r : "" + r)
  }

  function notify(headline, body) {
    if (!root.omarchyPath) return
    Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-notification-send", "-g", "󰈈", headline, body])
  }

  function summonOverlay() {
    if (root.shell && typeof root.shell.summon === "function")
      root.shell.summon(root.pluginId, "{}")
  }

  function hideOverlay() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId)
  }

  function startWork() {
    root.phase = "work"
    root.remaining = root.workSeconds
  }

  function startRest() {
    root.phase = "rest"
    root.remaining = root.restSeconds
    root.notify("Rest your eyes", "Look 20 feet away for 20 seconds and blink consciously")
    root.summonOverlay()
  }

  function finishRest() {
    root.hideOverlay()
    root.notify("Break over", "You can get back to work")
    root.startWork()
  }

  // Pause/resume toggle. Independent from the plugin's enable/disable state.
  function toggle() {
    root.paused = !root.paused
  }

  function start() {
    root.paused = false
  }

  function stop() {
    root.paused = true
  }

  // Skip the current phase. work → rest immediately, rest → back to work.
  function skip() {
    if (root.phase === "rest") root.finishRest()
    else root.startRest()
  }

  function tick() {
    if (root.paused) return
    root.remaining -= 1
    if (root.remaining > 0) return
    if (root.phase === "work") root.startRest()
    else root.finishRest()
  }

  Timer {
    id: ticker
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.tick()
  }

  function statusJson() {
    return JSON.stringify({
      phase: root.phase,
      remaining: root.remaining,
      display: root.formatTime(root.remaining),
      paused: root.paused
    })
  }

  IpcHandler {
    target: "eye-care"

    function status(): string { return root.statusJson() }
    function start(): string { root.start(); return root.statusJson() }
    function stop(): string { root.stop(); return root.statusJson() }
    function toggle(): string { root.toggle(); return root.statusJson() }
    function skip(): string { root.skip(); return root.statusJson() }
    function ping(): string { return "ok" }
  }
}
