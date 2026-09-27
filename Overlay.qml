import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// 20秒休憩の全画面カウントダウン overlay。
// Service.qml が work 完了時に shell.summon() で開く。
// 閉じられる (reminders準拠): カード外クリック・Esc・ボタンで中断し、
// 中断時は Service.finishRest() 経由で次の work 周期へ進む。
Item {
  id: root

  property var shell: null
  property var manifest: null
  // omarchy-shell が同プラグインの service エントリを注入する
  // (shell.qml の panelEntries ローダーの契約)。service がまだ無い
  // タイミングに備えて serviceFor 参照をフォールバックに使う。
  property var service: null

  property bool opened: false

  readonly property var eyeService: root.service ? root.service : (shell ? shell.serviceFor("usutani.eye-care") : null)
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
    // 休憩中なら Service 側で復帰通知 + work 周期へ。そうでなければ閉じるだけ。
    if (root.eyeService && String(root.eyeService.phase) === "rest") root.eyeService.finishRest()
    else if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide("usutani.eye-care")
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
    WlrLayershell.namespace: "usutani-eye-care"
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
          text: "目を休めましょう"
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

        // 残り時間プログレスバー
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
          text: "20秒間、6m先 (窓の外など) を見て、\n意識して瞬きしてください"
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
          text: "画面との距離は 50〜60cm、画面は目線より下に"
          color: root.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
        }

        Button {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "作業に戻る"
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
