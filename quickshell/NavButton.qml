// Small square button for the calendar header. Either a chevron (rotated to
// point where it goes) or a short word.

import QtQuick

Rectangle {
    id: root

    property string label: ""
    property bool wide: false
    property int rotation: 0
    // Set from outside by whatever is driving keyboard navigation.
    property bool focused: false

    signal triggered

    width: wide ? 44 : 24
    height: 24
    radius: Theme.radius
    color: navMouse.containsMouse ? Theme.surface1 : "transparent"
    border.width: focused ? 2 : 0
    border.color: Theme.accent

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }

    Icon {
        anchors.centerIn: parent
        visible: root.label === ""
        name: "chevron"
        size: 14
        color: Theme.subtext
        rotation: root.rotation
    }

    Text {
        anchors.centerIn: parent
        visible: root.label !== ""
        text: root.label
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }

    MouseArea {
        id: navMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
