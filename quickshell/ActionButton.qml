// A labelled button.
//
// Until now nothing needed one: every panel had an action or two and drew them
// inline as rows. The Tailscale window has a dozen, and a dozen hand-drawn
// rectangles drift apart within a week, so this is the one button shape.
//
// Three weights, and the difference between them is consequence, not decoration
// -- primary for the thing you came here to do, danger for the ones that undo
// something, plain for the rest.

import QtQuick

Rectangle {
    id: root

    property string label: ""
    property bool primary: false
    property bool danger: false

    signal triggered

    implicitWidth: caption.implicitWidth + Theme.pad * 2
    implicitHeight: 26
    radius: Theme.radius
    opacity: enabled ? 1 : 0.4

    color: !enabled ? Theme.surface0 : primary ? (mouse.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent) : danger ? (mouse.containsMouse ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.18) : Theme.surface0) : (mouse.containsMouse ? Theme.surface1 : Theme.surface0)

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }

    Text {
        id: caption
        anchors.centerIn: parent
        text: root.label
        color: root.primary ? Theme.base : root.danger ? Theme.red : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
