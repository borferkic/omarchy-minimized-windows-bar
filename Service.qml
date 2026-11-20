import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

// One slim bar per monitor, anchored to the bottom edge, that only appears
// while that monitor has minimized windows. Colors, font and height come from
// the active theme, so it follows theme switches with the top bar.
Item {
  id: root

  property var wins: []
  readonly property string helper: Qt.resolvedUrl("bin/minimized-windows-bar").toString().replace("file://", "")

  // Retro pixel-art font for the brackets, shipped with the plugin (SIL OFL, see fonts/OFL.txt).
  // It is drawn on an 8px grid, so its size snaps to a multiple of 8 to keep
  // the pixels crisp.
  FontLoader { id: pixelFont; source: Qt.resolvedUrl("fonts/PressStart2P-Regular.ttf") }
  readonly property string fontFamily: pixelFont.status === FontLoader.Ready ? pixelFont.name : Style.font.family
  readonly property int fontSize: Math.max(8, Math.round(Style.font.subtitle / 8) * 8)

  Process {
    id: lister
    command: [root.helper, "list"]
    stdout: StdioCollector {
      onStreamFinished: { try { root.wins = JSON.parse(text) } catch (e) {} }
    }
  }
  // Refresh on Hyprland events instead of polling. The short debounce folds
  // the burst a minimize/restore produces into one `list` call.
  Timer { id: refresh; interval: 80; onTriggered: lister.running = true }
  Component.onCompleted: lister.running = true
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = String(event.name)
      if (name === "movewindowv2" || name === "openwindow" || name === "closewindow") {
        refresh.restart()
      } else if (name === "windowtitlev2") {
        // only titles of minimized windows matter
        var addr = "0x" + String(event.data).split(",")[0]
        if (root.wins.some(function(w) { return w.address === addr })) refresh.restart()
      }
    }
  }
  Process { id: restorer }
  Process { id: closer }

  function restore(addrs) {
    restorer.command = [root.helper, "restore"].concat(addrs)
    restorer.running = true
  }
  function closeWindow(addr) {
    closer.command = ["hyprctl", "dispatch", "hl.dsp.window.close({ window = \"address:" + addr + "\" })"]
    closer.running = true
  }

  Variants {
    model: Quickshell.screens
    delegate: PanelWindow {
      id: bar
      required property var modelData
      screen: modelData
      // windows minimized before monitors were recorded go to the first screen
      readonly property var mine: root.wins.filter(function(w) {
        return (w.monitor !== "" ? w.monitor : Quickshell.screens[0].name) === modelData.name
      })
      readonly property bool shown: mine.length > 0
      readonly property real fullHeight: Style.bar.sizeHorizontal
      // the reserved space grows and shrinks with the bar, so windows resize
      // smoothly instead of jumping when the first window is minimized
      anchors { bottom: true; left: true; right: true }
      implicitHeight: shown ? fullHeight : 0
      Behavior on implicitHeight {
        NumberAnimation {
          duration: Style.duration(bar.shown ? 180 : 120)
          easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut
        }
      }
      visible: shown || implicitHeight > 0
      color: Commons.Color.bar.background
      WlrLayershell.namespace: "omarchy-minimized-windows-bar"

      // hovered button, for the tooltip with the full title
      property Item tipTarget: null
      property string tipText: ""
      Timer { id: tipDelay; interval: 400; onTriggered: tip.visible = bar.tipTarget !== null }

      PopupWindow {
        id: tip
        visible: false
        color: "transparent"
        implicitWidth: Math.ceil(tipBox.implicitWidth)
        implicitHeight: Math.ceil(tipBox.implicitHeight)
        anchor {
          window: bar
          adjustment: PopupAdjustment.Slide
          edges: Edges.Top | Edges.Left
          gravity: Edges.Top | Edges.Right
          rect.width: 1
          rect.height: 1
          onAnchoring: {
            if (!bar.tipTarget) return
            var p = bar.tipTarget.mapToItem(null, 0, 0)
            tip.anchor.rect.x = p.x
            tip.anchor.rect.y = p.y - 6
          }
        }
        Rectangle {
          id: tipBox
          implicitWidth: Math.min(tipLabel.implicitWidth, Style.space(600)) + Style.space(16)
          implicitHeight: tipLabel.implicitHeight + Style.space(10)
          radius: Style.cornerRadius
          color: Commons.Color.tooltip.background
          border { width: 1; color: Commons.Color.tooltip.border }
          Text {
            id: tipLabel
            anchors.centerIn: parent
            width: Math.min(implicitWidth, Style.space(600))
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: bar.tipText
            color: Commons.Color.tooltip.text
            font { family: Style.font.family; pixelSize: Style.font.bodySmall }
          }
        }
      }

      Row {
        id: row
        anchors { fill: parent; leftMargin: Style.space(8); rightMargin: Style.space(8) }
        spacing: Style.space(8)
        // share the width evenly once the buttons no longer fit at full size
        readonly property real slot: Math.min(Style.space(300),
          (width - spacing * Math.max(0, bar.mine.length - 1)) / Math.max(1, bar.mine.length))
        Repeater {
          model: bar.mine
          delegate: Item {
            id: btn
            required property var modelData
            readonly property var entry: DesktopEntries.heuristicLookup(modelData["class"])
            readonly property string fallbackName: {
              var last = String(modelData["class"]).split(".").pop()
              return last.charAt(0).toUpperCase() + last.slice(1)
            }
            readonly property string appName: entry && entry.name ? entry.name : fallbackName
            width: Math.min(row.slot, label.implicitWidth + openBracket.implicitWidth + closeBracket.implicitWidth + Style.space(24))
            height: parent.height

            Rectangle {
              anchors { fill: parent; topMargin: 2; bottomMargin: 2 }
              color: Commons.Color.bar.text
              opacity: ma.containsMouse ? 0.12 : 0
            }
            // retro look: every window sits between brackets, which also
            // separate one window from the next. They live outside the label
            // so eliding a long title never eats the closing bracket.
            Text {
              id: openBracket
              anchors { left: parent.left; leftMargin: Style.space(6); verticalCenter: parent.verticalCenter }
              color: Commons.Color.bar.text
              font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
              textFormat: Text.PlainText
              text: "["
            }
            Text {
              id: closeBracket
              anchors { right: parent.right; rightMargin: Style.space(6); verticalCenter: parent.verticalCenter }
              color: Commons.Color.bar.text
              font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
              textFormat: Text.PlainText
              text: "]"
            }
            Text {
              id: label
              anchors { left: openBracket.right; leftMargin: Style.space(6); right: closeBracket.left; rightMargin: Style.space(6); verticalCenter: parent.verticalCenter }
              elide: Text.ElideRight
              color: Commons.Color.bar.text
              font { family: Style.font.family; pixelSize: Style.font.subtitle }
              // window titles are outside text: never render them as markup
              textFormat: Text.PlainText
              text: btn.modelData.title !== "" ? btn.appName + " - " + btn.modelData.title : btn.appName
            }
            MouseArea {
              id: ma
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
              onContainsMouseChanged: {
                if (containsMouse) {
                  bar.tipTarget = btn
                  bar.tipText = label.text
                  tip.visible = false
                  tipDelay.restart()
                } else if (bar.tipTarget === btn) {
                  bar.tipTarget = null
                  tipDelay.stop()
                  tip.visible = false
                }
              }
              onClicked: function(mouse) {
                tip.visible = false
                if (mouse.button === Qt.MiddleButton) {
                  root.closeWindow(btn.modelData.address)
                } else if (mouse.button === Qt.RightButton) {
                  root.restore(bar.mine.map(function(w) { return w.address }))
                } else {
                  root.restore([btn.modelData.address])
                }
              }
            }
          }
        }
      }
    }
  }
}
