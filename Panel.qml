import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Settings panel for the eye-care plugin. Loaded by BarWidget.qml, so it
// inherits Panel's opened/open/close/toggle from the shell and is
// positioned against the bar button.
Panel {
  id: root
  moduleName: "towhid.eye-care"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  // Injected when the bar widget hands its service over; otherwise looked
  // up from the shell.
  property var service: null

  readonly property var eyeService: root.service
    ? root.service
    : (root.bar && root.bar.shell ? root.bar.shell.serviceFor("towhid.eye-care") : null)

  readonly property color fg: root.barForeground

  // open/close/toggle are inherited from Panel, which drives the
  // KeyboardPanel through `open: root.opened` -> panelController.show().
  // Do not redefine open() here: an earlier version shadowed the base
  // implementation with a no-op that looked for panel.item, so the panel
  // never actually opened.

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        // ------------------------------------------------ bar display
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: "Bar display"
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        ButtonGroup {
          width: parent.width
          value: root.eyeService ? root.eyeService.barMode : "compact"
          options: [
            { value: "full", label: "Full" },
            { value: "compact", label: "Ring" },
            { value: "hover", label: "Hover" }
          ]
          onChanged: function(value) {
            if (root.eyeService) root.eyeService.setBarMode(value)
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.WordWrap
          text: root.eyeService && root.eyeService.barMode === "compact"
            ? "Icon with a ring that fills as the 20 minutes run. No numbers, no hover needed."
            : (root.eyeService && root.eyeService.barMode === "hover"
                ? "Icon only until you hover it, then the timer slides in."
                : "Icon plus the countdown, as before.")
          color: Util.alpha(root.fg, 0.6)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.WordWrap
          opacity: 0.45
          text: "A wellness habit, not medical advice. Rest your eyes often, and see a doctor if they hurt."
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
