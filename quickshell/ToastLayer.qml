// Where toasts live: a column under the bar on the right.
//
// The window is sized to its contents rather than to the screen. A full-screen
// transparent layer would be simpler but would swallow every click on the
// desktop for as long as any notification was showing, which is intolerable for
// something that appears unbidden.

import Quickshell
import Quickshell.Wayland
import QtQuick

Scope {
    id: root

    required property var modelData

    // Five is enough to see a burst without the column reaching the taskbar of
    // a 1080p screen. The rest stay in history.
    readonly property int maxVisible: 5
    readonly property var shown: Notifs.popups.slice(0, maxVisible)

    PanelWindow {
        screen: root.modelData
        visible: root.shown.length > 0

        anchors {
            top: true
            right: true
        }

        implicitWidth: Theme.popoutWidth + Theme.gap * 2
        implicitHeight: Math.max(1, column.implicitHeight + Theme.gap * 2)

        // Must not reserve space, or every notification would shove the desktop
        // sideways and back.
        exclusiveZone: 0
        color: "transparent"

        // Never take the keyboard. A notification that steals focus mid-sentence
        // is worse than a missed notification.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.layer: WlrLayer.Overlay

        Column {
            id: column
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Theme.gap
            anchors.rightMargin: Theme.gap
            spacing: Theme.gap

            Repeater {
                model: root.shown

                Toast {
                    required property var modelData
                    notif: modelData
                }
            }
        }
    }
}
