// A single clickable item in the bar.
//
// Deliberately uniform: every indicator is the same height and padding, so a run
// of them reads as one control strip rather than a row of unrelated widgets. The
// only thing that varies is what is inside it.
//
// It does not know where it is. An indicator can be dragged into any of the
// bar's three zones, so the distance the popout anchors on is measured by the
// bar through the scene, not from this item's own `x`.

import QtQuick

Rectangle {
    id: root

    property string name: ""
    property bool active: false
    property alias content: slot.data

    signal activated
    signal scrolled(int delta)   // +1 up, -1 down
    signal middleClicked

    implicitWidth: slot.implicitWidth + Theme.pad * 2
    implicitHeight: Theme.barHeight - 8

    radius: Theme.radius
    // Active, pressed, hover, idle -- in that priority order, and the only
    // place any indicator decides what those states look like. A widget that
    // recolours its own icon on top of this is reinventing the state it
    // already has.
    color: active ? Theme.surface1 : mouse.pressed ? Theme.surface2 : mouse.containsMouse ? Theme.surface0 : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }

    Row {
        id: slot
        anchors.centerIn: parent
        spacing: Theme.contentSpacing
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
