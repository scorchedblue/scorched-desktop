// StatusNotifierItem host: tray icons belonging to other applications.
//
// Distinct from the indicators to its right, which are ours and describe the
// system. This row is whatever Steam, a chat client or a VPN GUI decides to
// put there, so it is deliberately plain -- it is not our design surface, and
// dressing it up would make foreign icons look like system state.
//
// The row collapses to nothing when empty rather than leaving a gap.

import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

Row {
    id: root
    spacing: 2
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items.values

        Rectangle {
            required property var modelData

            width: Theme.barHeight - 12
            height: Theme.barHeight - 12
            radius: Theme.radius
            color: itemMouse.containsMouse ? Theme.surface0 : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Theme.anim
                }
            }

            Image {
                anchors.centerIn: parent
                width: Theme.iconSize
                height: Theme.iconSize
                // An item that supplies no usable icon renders nothing rather
                // than a broken-image glyph.
                source: modelData.icon || ""
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                id: itemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: mouse => {
                    // activate() is the SNI primary action. Right-click is
                    // conventionally the item's menu; Quickshell exposes that
                    // separately and it is not wired up yet, so a right-click
                    // falls back to the secondary action rather than doing
                    // nothing at all.
                    if (mouse.button === Qt.RightButton)
                        modelData.secondaryActivate();
                    else
                        modelData.activate();
                }
            }
        }
    }

    // A hairline between foreign icons and ours, so the two groups do not read
    // as one row of equals.
    Rectangle {
        width: 1
        height: Theme.iconSize
        color: Theme.surface1
        anchors.verticalCenter: parent.verticalCenter
        visible: SystemTray.items.values.length > 0
    }
}
