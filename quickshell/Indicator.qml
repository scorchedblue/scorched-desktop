// A single clickable item in the bar's right-hand tray.
//
// Deliberately uniform: every indicator is the same height and padding, so the
// tray reads as one control strip rather than a row of unrelated widgets. The
// only thing that varies is what is inside it.

import QtQuick

Rectangle {
    id: root

    property string name: ""
    property bool active: false
    property alias content: slot.data
    // Distance from the bar's right edge to this item's centre. The popout uses
    // it to sit under whatever was clicked.
    readonly property real centreFromRight: parent ? parent.width - (x + width / 2) : 0

    signal activated
    signal scrolled(int delta)   // +1 up, -1 down
    signal middleClicked

    implicitWidth: slot.implicitWidth + Theme.pad * 2
    implicitHeight: Theme.barHeight - 8

    radius: Theme.radius
    color: active ? Theme.surface1 : mouse.containsMouse ? Theme.surface0 : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }

    Row {
        id: slot
        anchors.centerIn: parent
        spacing: 6
    }

    // Scroll and middle-click are wired for every indicator even though only
    // some use them. An indicator that ignores a scroll simply does nothing,
    // which is better than each one inventing its own input handling.
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                root.middleClicked();
            else
                root.activated();
        }

        onWheel: wheel => root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1)
    }
}
