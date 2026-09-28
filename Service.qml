import QtQuick
import Quickshell
import Quickshell.Io

// Timer core for the 20-20-20 rule (single source of truth).
// 20 minutes of work → 20 seconds of rest → repeat. Fixed values.
// BarWidget / Overlay reference this instance via
// shell.serviceFor("towhid.eye-care") and display phase / remaining / paused.
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || root.home + "/.local/state") + "/omarchy/towhid.eye-care/"
  readonly property string settingsPath: root.stateDir + "timer.json"

  readonly property string pluginId: "towhid.eye-care"

  // 20-20-20 rule: every 20 minutes, look at something
  // 20 feet away for 20 seconds.
  readonly property int workSeconds: 1200
  readonly property int restSeconds: 20

  // Bar display: "full" shows icon and timer, "compact" shows icon plus a
  // progress ring, "hover" reveals the timer while the pointer is on the
  // widget.
  property string barMode: "compact"
  readonly property var barModes: ["full", "compact", "hover"]

  // Fraction of the 20-minute work phase already elapsed.
  readonly property real progress: root.phase !== "work" || root.workSeconds <= 0
    ? 1
    : Math.min(1, Math.max(0, 1 - root.remaining / root.workSeconds))

  // Wall-clock anchor for the work countdown, in epoch milliseconds.
  // 0 means "not counting down" (paused). Storing an absolute deadline
  // instead of a remaining-seconds counter lets the timer survive
  // `omarchy restart shell`: the new process subtracts the current time
  // from the deadline the old one wrote, so the countdown resumes where
  // it would have been rather than starting over at 20:00.
  //
  // Must be `double`, not `int`: a millisecond epoch is around 1.79e12 and
  // silently overflows a 32-bit QML int (max ~2.1e9), which would make
  // every restored countdown read as already expired.
  property double deadline: 0

  // "work" | "rest"
  property string phase: "work"
  property int remaining: workSeconds
  // The rest countdown has run out but the overlay is still up, waiting
  // for a deliberate dismiss. The break is a full-screen block now, so it
  // must not vanish on its own: if the user stepped away mid-break, an
  // auto-dismiss would hand the screen straight back before they saw it.
  property bool restDone: false
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

  // Arm (or disarm) the work countdown. Everything that starts, resumes
  // or re-times the work phase goes through here, so the persisted
  // deadline and the on-screen number can never disagree.
  function armWorkCountdown(seconds) {
    var s = Math.max(0, seconds)
    root.remaining = s
    root.deadline = s > 0 ? Date.now() + s * 1000 : 0
    root.scheduleSave()
  }

  // Recompute the display from the wall clock. Deriving instead of
  // decrementing also stops the countdown from drifting when a tick is
  // late or the system is briefly busy.
  function syncRemaining() {
    if (root.paused || root.deadline === 0) return
    root.remaining = Math.max(0, Math.ceil((root.deadline - Date.now()) / 1000))
  }

  function startWork() {
    root.phase = "work"
    root.armWorkCountdown(root.workSeconds)
  }

  // --------------------------------------------------- media playback guard
  // A break that only blacks out the screen is useless during a film: the
  // audio keeps going and the video keeps advancing behind the block, so
  // nothing is actually restful and the film plays on regardless. Pause
  // whatever is playing when the break opens, and resume exactly that set
  // when it is dismissed.
  //
  // MPRIS is spoken directly over busctl; playerctl is not installed here.
  // Two rules keep this from being obnoxious: only a player found in the
  // Playing state is ever touched, and only the players we paused are
  // resumed, so a track the user paused themselves never starts up behind
  // their back.
  property var mediaPausedBy: []
  readonly property bool mediaActive: mediaPausedBy.length > 0

  // Single line on purpose: this is handed to `bash -c` as one string, and
  // a multi-line if/then does not survive being joined into one.
  readonly property string mediaScanCommand:
    "for b in $(busctl --user list --no-pager 2>/dev/null | awk '$1 ~ /^org\\.mpris\\.MediaPlayer2\\./ {print $1}'); do "
    + "busctl --user get-property \"$b\" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player PlaybackStatus 2>/dev/null | grep -q Playing "
    + "&& busctl --user call \"$b\" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player Pause >/dev/null 2>&1 "
    + "&& echo \"$b\"; done"

  readonly property string mediaPlayCommand:
    "for b in \"$@\"; do busctl --user call \"$b\" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player Play >/dev/null 2>&1; done"

  // Echoes one bus name per line, and only for players it actually paused.
  Process {
    id: mediaScan
    command: ["bash", "-c", root.mediaScanCommand]
    stdout: StdioCollector {
      id: mediaScanOut
      onStreamFinished: {
        var names = mediaScanOut.text.split("\n").filter(function(n) { return n.length > 0 })
        if (names.length > 0) root.mediaPausedBy = names
      }
    }
  }

  Process {
    id: mediaPlay
    property var targets: []
    command: ["bash", "-c", root.mediaPlayCommand, "media-resume"].concat(targets)
  }

  function pauseMedia() {
    if (mediaScan.running) return
    mediaScan.running = true
  }

  function resumeMedia() {
    if (mediaPausedBy.length === 0) return
    // Hand the list to the process before clearing it, so a second dismiss
    // within one break cannot resume the same player twice.
    mediaPlay.targets = mediaPausedBy
    root.mediaPausedBy = []
    mediaPlay.running = true
  }

  function startRest() {
    root.phase = "rest"
    root.restDone = false
    // The rest countdown is a plain 20-second counter, not a deadline:
    // it is far too short to be worth resuming, and the overlay reads
    // `remaining` directly for its countdown.
    root.remaining = root.restSeconds
    // The work countdown is over; clear the deadline so a restart during
    // the break cannot resurrect a stale one.
    root.deadline = 0
    root.scheduleSave()
    root.notify("Rest your eyes", "Look 20 feet away for 20 seconds and blink consciously")
    root.pauseMedia()
    root.summonOverlay()
  }

  function finishRest() {
    root.resumeMedia()
    root.hideOverlay()
    root.notify("Break over", "You can get back to work")
    root.startWork()
  }

  // Pause/resume toggle. Independent from the plugin's enable/disable state.
  // Pausing freezes the number and drops the deadline; resuming re-arms it
  // from whatever was left, so a pause that outlived a restart does not
  // come back already expired.
  function toggle() {
    if (root.paused) root.resume()
    else root.pause()
  }

  function pause() {
    if (root.paused) return
    root.syncRemaining()
    root.paused = true
    root.deadline = 0
    root.scheduleSave()
  }

  function resume() {
    if (!root.paused) return
    root.paused = false
    if (root.phase === "work") root.armWorkCountdown(root.remaining)
    else root.scheduleSave()
  }

  function start() {
    root.resume()
  }

  function stop() {
    // Never leave somebody's film parked on pause because the plugin was
    // switched off mid-break.
    root.resumeMedia()
    root.pause()
  }

  // Skip the current phase. work → rest immediately, rest → back to work.
  function skip() {
    if (root.phase === "rest") root.finishRest()
    else root.startRest()
  }

  function tick() {
    if (root.paused) return

    if (root.phase === "work") {
      root.syncRemaining()
      if (root.remaining > 0) return
      root.startRest()
      return
    }

    // Latch at zero. The overlay stays up and keeps the screen blocked
    // until the user dismisses it, which is what calls finishRest().
    if (root.restDone) return
    root.remaining -= 1
    if (root.remaining > 0) return
    root.restDone = true
  }

  Timer {
    id: ticker
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.tick()
  }

  // ------------------------------------------------------ timer persistence
  //
  // The countdown survives `omarchy restart shell` by writing an absolute
  // deadline whenever the work phase is (re)armed. That is a handful of
  // writes per work cycle rather than one per second.

  Process {
    id: ensureDirs
    command: ["mkdir", "-p", root.stateDir]
    running: false
  }

  FileView {
    id: timerFile
    path: root.settingsPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.restoreTimer(text())
    onLoadFailed: root.restoreTimer("")
  }

  Timer {
    id: saveTimer
    interval: 200
    repeat: false
    onTriggered: root.flushTimer()
  }

  function scheduleSave() {
    if (!root.timerLoaded) return
    saveTimer.restart()
  }

  function setBarMode(value) {
    if (root.barModes.indexOf(String(value)) < 0) return false
    if (root.barMode === String(value)) return true
    root.barMode = String(value)
    root.scheduleSave()
    return true
  }

  function flushTimer() {
    timerFile.setText(JSON.stringify({
      version: 1,
      phase: root.phase,
      deadline: root.deadline,
      remaining: root.remaining,
      paused: root.paused,
      barMode: root.barMode
    }, null, 2) + "\n")
  }

  // Rebuild the countdown from disk. The persisted deadline wins over the
  // persisted remaining count: the shell may have been stopped for a few
  // seconds (a restart) or for hours (a reboot), and only the wall clock
  // can tell those apart. A deadline that already elapsed while the shell
  // was down falls back to a fresh 20 minutes instead of firing a stale
  // eye break at login.
  function restoreTimer(raw) {
    // FileView can fire onLoaded more than once during startup (the
    // implicit preload plus the explicit reload in Component.onCompleted).
    // Re-arming on the second call would throw away the restored deadline.
    if (root.timerLoaded) return

    var parsed = {}
    try { parsed = JSON.parse(raw || "{}") || {} } catch (e) { parsed = {} }

    if (typeof parsed.paused === "boolean") root.paused = parsed.paused
    if (root.barModes.indexOf(String(parsed.barMode)) >= 0) root.barMode = String(parsed.barMode)
    root.timerLoaded = true

    // Only a work phase is resumable. A 20-second rest interrupted by the
    // restart is not worth replaying.
    if (parsed.phase !== "work") {
      root.startWork()
      return
    }

    var left = 0
    if (!root.paused && typeof parsed.deadline === "number" && parsed.deadline > 0)
      left = Math.ceil((parsed.deadline - Date.now()) / 1000)
    else if (typeof parsed.remaining === "number")
      left = parsed.remaining

    if (left <= 0) {
      root.startWork()
      return
    }

    root.phase = "work"
    root.remaining = left
    root.deadline = root.paused ? 0 : Date.now() + left * 1000
  }

  property bool timerLoaded: false

  Component.onCompleted: {
    ensureDirs.running = true
    // Once mkdir has had a tick, read the persisted deadline. Reading
    // after the directory exists keeps the first run (no file yet) from
    // reporting a path error instead of a missing file.
    Qt.callLater(function() {
      timerFile.reload()
    })
  }

  function statusJson() {
    return JSON.stringify({
      phase: root.phase,
      remaining: root.remaining,
      display: root.formatTime(root.remaining),
      deadline: root.deadline,
      paused: root.paused,
      restDone: root.restDone,
      mediaActive: root.mediaActive,
      barMode: root.barMode,
      progress: Math.round(root.progress * 1000) / 1000
    })
  }

  IpcHandler {
    target: "eye-care"

    function status(): string { return root.statusJson() }
    function start(): string { root.start(); return root.statusJson() }
    function stop(): string { root.stop(); return root.statusJson() }
    function toggle(): string { root.toggle(); return root.statusJson() }
    function skip(): string { root.skip(); return root.statusJson() }
    function mode(value: string): string { root.setBarMode(value); return root.statusJson() }
    function ping(): string { return "ok" }
  }
}
