import QtQuick
import qs.Ui

// バーの残り時間表示。タイマー実体は Service.qml が持ち、
// ここは shell.serviceFor() 経由の読み取り専用表示 + 簡易操作。
BarWidget {
  id: root
  moduleName: "usutani.eye-care"

  readonly property var eyeService: bar && bar.shell ? bar.shell.serviceFor("usutani.eye-care") : null
  readonly property string phase: eyeService ? String(eyeService.phase) : "work"
  readonly property int remaining: eyeService ? Number(eyeService.remaining) : 1200
  readonly property bool paused: eyeService ? !!eyeService.paused : false

  readonly property bool resting: root.phase === "rest"

  function formatTime(totalSeconds) {
    var s = Math.max(0, totalSeconds)
    var m = Math.floor(s / 60)
    var r = s % 60
    return m + ":" + (r < 10 ? "0" + r : "" + r)
  }

  readonly property string labelText: (root.resting ? "休憩 " : "") + root.formatTime(root.remaining)
  readonly property string tooltipText: root.paused
    ? "Eye Care: 一時停止中 (左クリックで再開、右クリックでスキップ)"
    : (root.resting ? "Eye Care: 休憩中 — 6m先を見てください" : "Eye Care: 次の休憩まで " + root.formatTime(root.remaining) + " (左クリックで一時停止)")

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰈈 " + root.labelText
    tooltipText: root.tooltipText
    active: root.resting || root.paused

    onPressed: function(b) {
      if (!root.eyeService) return
      if (b === Qt.RightButton) root.eyeService.skip()
      else root.eyeService.toggle()
    }
  }
}
