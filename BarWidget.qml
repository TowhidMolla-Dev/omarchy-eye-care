import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Bar countdown display. The timer itself lives in Service.qml;
// this is a read-only view plus quick controls via shell.serviceFor().
BarWidget {
  id: root
  moduleName: "towhid.eye-care"

  readonly property var eyeService: bar && bar.shell ? bar.shell.serviceFor("towhid.eye-care") : null
  readonly property string phase: eyeService ? String(eyeService.phase) : "work"
  readonly property int remaining: eyeService ? Number(eyeService.remaining) : 1200
  readonly property bool paused: eyeService ? !!eyeService.paused : false

  readonly property bool resting: root.phase === "rest"

  // ------------------------------------------------------- bar layout mode
  readonly property string barMode: eyeService ? String(eyeService.barMode) : "compact"
  readonly property real progress: eyeService ? Number(eyeService.progress) : 0
  readonly property bool compact: barMode === "compact"
  readonly property bool hoverMode: barMode === "hover"
  readonly property bool urgent: resting || paused

  // Decoupled from what is drawn, so collapsing the widget never slides its
  // own hit area out from under the pointer and re-enters immediately.
  property bool pointerInside: false
  property bool showTimer: false
  readonly property bool hovered: compact ? false
    : (showTimer || pointerInside || (panelLoader.item ? panelLoader.item.opened : false))

  Timer {
    id: collapseDelay
    interval: 280
    onTriggered: root.showTimer = false
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function formatTime(totalSeconds) {
    var s = Math.max(0, totalSeconds)
    var m = Math.floor(s / 60)
    var r = s % 60
    return m + ":" + (r < 10 ? "0" + r : "" + r)
  }

  readonly property string labelText: (root.resting ? "Break " : "") + root.formatTime(root.remaining)

  readonly property string buttonText: root.hoverMode
    ? (root.hovered ? "󰈈 " + root.labelText : "󰈈")
    : (root.compact ? "󰈈" : "󰈈 " + root.labelText)

  readonly property string tooltipText: root.paused
    ? "Eye Care: paused (left-click to resume, right-click to skip)"
    : (root.resting ? "Eye Care: on a break — look far away (left-click to pause)"
      : "Eye Care: " + root.formatTime(root.remaining) + " until the next break (left-click to pause, middle-click for settings)")

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false

    onLoaded: {
      // Bind, do not assign. The Bar is attached to this widget *after*
      // this handler runs, so a one-shot `= root.bar` captured null and
      // the panel could never reach the service: every control fell back
      // to its default and the mode chips ignored clicks. Qt.binding
      // re-evaluates as soon as the source property changes.
      panelLoader.item.bar = Qt.binding(function() { return root.bar })
      panelLoader.item.service = Qt.binding(function() { return root.eyeService })
      panelLoader.item.anchorItem = button
      panelLoader.item.hostWidget = root
    }
  }

  // Behind the glyph: in compact mode the ring is the only thing carrying
  // elapsed time, so it sits under the icon rather than beside it.
  ProgressRing {
    visible: root.compact
    width: button.height
    height: button.height
    anchors.horizontalCenter: button.horizontalCenter
    anchors.verticalCenter: button.verticalCenter
    progress: root.progress
    trackColor: Util.alpha(
      root.urgent ? (root.bar ? root.bar.urgent : Color.urgent) : root.barForeground,
      0.22
    )
    progressColor: root.urgent
      ? (root.bar ? root.bar.urgent : Color.urgent)
      : Color.accent
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.buttonText
    tooltipText: root.tooltipText
    active: root.urgent

    // The bar sizes each slot from implicitWidth, so animating it here
    // slides the rest of the bar instead of teleporting it.
    Behavior on implicitWidth {
      NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    onPressed: function(b) {
      if (!root.eyeService) return
      if (b === Qt.RightButton) root.eyeService.skip()
      else if (b === Qt.MiddleButton) root.open()
      else root.eyeService.toggle()
    }
  }

  // Middle click is handled here, on press, instead of relying on
  // WidgetButton's onClicked -- that fires only when the press *and* the
  // release land inside the item. In hover mode this widget animates its
  // width as the pointer enters, so a click that straddles the animation
  // releases outside the resized item and onClicked is cancelled: the
  // settings silently never opened. Only the middle button is accepted, so
  // left and right clicks still fall through to the button below.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton
    onPressed: {
      console.log("EYEDIAG middle press; widgetWidth=" + root.width)
      root.open()
    }
  }

  Connections {
    target: button
    function onTooltipHoveredChanged() {
      if (button.tooltipHovered) {
        collapseDelay.stop()
        root.pointerInside = true
        root.showTimer = true
      } else {
        root.pointerInside = false
        collapseDelay.restart()
      }
    }
  }
}
