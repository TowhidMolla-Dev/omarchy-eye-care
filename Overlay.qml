import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Fullscreen 20-second break countdown overlay.
// Service.qml opens it via shell.summon() when a work phase ends.
// Dismissible (reminders-style): clicking outside the card, Esc, or the
// button interrupts the break, and Service.finishRest() moves on to the
// next work phase.
Item {
  id: root

  property var shell: null
  property var manifest: null
  // omarchy-shell injects the matching service singleton when the item
  // declares a `service` property (panelEntries loader contract in shell.qml).
  // Falls back to a serviceFor lookup in case the service is not loaded yet.
  property var service: null

  property bool opened: false

  readonly property var eyeService: root.service ? root.service : (shell ? shell.serviceFor("towhid.eye-care") : null)
  readonly property int restTotal: eyeService ? Number(eyeService.restSeconds) : 20
  readonly property int countdown: (eyeService && String(eyeService.phase) === "rest") ? Number(eyeService.remaining) : restTotal
  readonly property real progress: restTotal > 0 ? 1 - (countdown / restTotal) : 0

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding

  function open(payloadJson) {
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    // On a break, let the Service announce the return and move to the
    // next work phase. Otherwise just close.
    if (root.eyeService && String(root.eyeService.phase) === "rest") root.eyeService.finishRest()
    else if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide("towhid.eye-care")
    else root.opened = false
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "towhid-eye-care"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: Math.min(Style.space(340), panel.width - Style.gapsOut * 2)
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      radius: root.cornerRadius
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Column {
        id: content
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.space(12)

        Text {
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: "Rest your eyes"
          color: root.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.displayLarge
          color: Color.accent
          text: root.countdown
        }

        // Remaining-time progress bar
        Rectangle {
          width: parent.width
          height: Style.space(8)
          radius: height / 2
          color: Util.alpha(root.foreground, 0.18)

          Rectangle {
            width: parent.width * Math.min(1, Math.max(0, root.progress))
            height: parent.height
            radius: parent.radius
            color: Color.accent
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          text: "For 20 seconds, look at something 20 ft away\n(e.g. outside the window) and blink consciously"
          color: root.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          opacity: 0.6
          text: "Keep the screen 50-60 cm away and below eye level"
          color: root.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
        }

        Button {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Back to work"
          onClicked: root.dismiss()
        }

        Item {
          id: keyCatcher
          width: 1
          height: 1
          focus: true
          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.dismiss()
              event.accepted = true
            }
          }
        }
      }
    }
  }
}
