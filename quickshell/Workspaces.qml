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

    // The Lua form, like every other dispatch in this shell. The old string
    // dispatchers went with the old config format in 0.56 -- PowerPanel.qml,
    // Actions.qml and screen-power.sh each record a different one failing as a
    // parse error, and AGENTS.md states the rule. This file was the holdout.
    //
    // `hl.dsp.focus({workspace = ...})` is not a guess: hyprland.lua:274-275
    // binds SUPER+mouse_down/up to exactly this call for exactly this
    // behaviour, so the shell already proves the form works. Note it is
    // `focus`, not `hl.dsp.workspace` -- that namespace only carries
    // change_id, move and rename.
    onWheel: wheel => Hyprland.dispatch(wheel.angleDelta.y > 0 ? 'hl.dsp.focus({workspace = "e-1"})' : 'hl.dsp.focus({workspace = "e+1"})')

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
                    onClicked: Hyprland.dispatch("hl.dsp.focus({workspace = " + modelData.id + "})")
                }
            }
        }
    }
}
