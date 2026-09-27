import QtQuick
import Quickshell
import Quickshell.Io

// 20-20-20ルールのタイマー本体 (single source of truth)。
// 20分作業 → 20秒休憩 → 繰り返し。固定値 (記事通り厳密運用)。
// BarWidget / Overlay は shell.serviceFor("usutani.eye-care") 経由で
// このインスタンスを参照し、phase / remaining / paused を表示する。
Item {
  id: root

  // omarchy-shell が注入するホスト参照。
  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  readonly property string pluginId: "usutani.eye-care"

  // 20-20-20ルール: 20分に1回、20秒間、20フィート (約6m) 先を見る。
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
    root.notify("目を休めましょう", "20秒間、6m先を見て、意識して瞬きしてください")
    root.summonOverlay()
  }

  function finishRest() {
    root.hideOverlay()
    root.notify("お疲れさまです", "作業を再開できます")
    root.startWork()
  }

  // 一時停止/再開の切り替え。プラグイン自体の enable/disable とは独立。
  function toggle() {
    root.paused = !root.paused
  }

  function start() {
    root.paused = false
  }

  function stop() {
    root.paused = true
  }

  // 今の区間を飛ばす。work → 即休憩、rest → 即復帰。
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
