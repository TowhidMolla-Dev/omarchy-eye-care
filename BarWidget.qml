import QtQuick
import qs.Ui

// Bar countdown display. The timer itself lives in Service.qml;
// this is a read-only view plus quick controls via shell.serviceFor().
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

  readonly property string labelText: (root.resting ? "Break " : "") + root.formatTime(root.remaining)
  readonly property string tooltipText: root.paused
    ? "Eye Care: paused (left-click to resume, right-click to skip)"
    : (root.resting ? "Eye Care: on a break — look far away" : "Eye Care: " + root.formatTime(root.remaining) + " until the next break (left-click to pause)")

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
