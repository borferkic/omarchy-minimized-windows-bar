import QtQuick
import Quickshell
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

  Process {
    id: lister
    command: [root.helper, "list"]
    stdout: StdioCollector {
      onStreamFinished: { try { root.wins = JSON.parse(text) } catch (e) {} }
    }
  }
  Timer { interval: 400; running: true; repeat: true; onTriggered: lister.running = true }
  Process { id: restorer }

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
      anchors { bottom: true; left: true; right: true }
      implicitHeight: Style.bar.sizeHorizontal
      visible: mine.length > 0
      color: Commons.Color.bar.background
      WlrLayershell.namespace: "omarchy-minimized-windows-bar"

      Row {
        anchors { fill: parent; leftMargin: Style.space(8); rightMargin: Style.space(8) }
        spacing: Style.space(17)
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
            width: Math.min(Style.space(300), label.implicitWidth + Style.space(16))
            height: parent.height

            Rectangle {
              anchors { fill: parent; topMargin: 2; bottomMargin: 2 }
              color: Commons.Color.bar.text
              opacity: ma.containsMouse ? 0.12 : 0
            }
            Text {
              id: label
              anchors { left: parent.left; leftMargin: Style.space(8); right: parent.right; rightMargin: Style.space(8); verticalCenter: parent.verticalCenter }
              elide: Text.ElideRight
              color: Commons.Color.bar.text
              font { family: Style.font.family; pixelSize: Style.font.subtitle }
              text: btn.modelData.title !== "" ? btn.appName + " - " + btn.modelData.title : btn.appName
            }
            // thin divider between buttons
            Rectangle {
              anchors { left: parent.right; leftMargin: Style.space(8); verticalCenter: parent.verticalCenter }
              visible: btn.modelData !== bar.mine[bar.mine.length - 1]
              width: 1; height: parent.height - 10
              color: Commons.Color.bar.text
              opacity: 0.2
            }
            MouseArea {
              id: ma
              anchors.fill: parent
              hoverEnabled: true
              onClicked: { restorer.command = [root.helper, "restore", btn.modelData.address]; restorer.running = true }
            }
          }
        }
      }
    }
  }
}
