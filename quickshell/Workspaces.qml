// Workspace pills.
//
// Hyprland is a singleton from Quickshell.Hyprland. Its `workspaces` is an
// ObjectModel, which QML cannot iterate directly -- `.values` exposes it as a
// list, which is what Repeater needs.
//
// The whole strip is a MouseArea so that scrolling anywhere over it moves
// between workspaces. That is the one piece of bar behaviour people reach for
// without being told it exists. The per-pill MouseArea inside handles clicks
// and does not take wheel events, so they fall through to this one.

import Quickshell.Hyprland
import QtQuick

MouseArea {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    onWheel: wheel => Hyprland.dispatch(wheel.angleDelta.y > 0 ? "workspace e-1" : "workspace e+1")

    Row {
        id: row
        spacing: 4

        Repeater {
            model: Hyprland.workspaces.values

            Rectangle {
                required property var modelData

                width: 26
                height: 20
                radius: 5
                color: modelData.focused ? Theme.accent : modelData.urgent ? Theme.red : wsMouse.containsMouse ? Theme.surface1 : Theme.surface0

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.anim
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.name
                    color: modelData.focused ? Theme.base : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: modelData.focused ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + modelData.id)
                }
            }
        }
    }
}
