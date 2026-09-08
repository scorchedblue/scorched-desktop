// One selectable audio device. Used for both sinks and sources.

import QtQuick

Rectangle {
    id: root

    property string label: ""
    property bool selected: false
    // Set from outside by whatever is driving keyboard navigation. Distinct
    // from `selected`, which means "this is the active device" -- a row can
    // be either, neither, or both at once.
    property bool focused: false
    signal picked

    height: 26
    radius: Theme.radius
    color: selected ? Theme.surface0 : devMouse.containsMouse ? Theme.surface0 : "transparent"
    border.width: focused ? 2 : 0
    border.color: Theme.accent

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Icon {
            name: root.selected ? "check" : "dot"
            size: root.selected ? 13 : 7
            color: root.selected ? Theme.green : Theme.overlay0
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.label
            color: root.selected ? Theme.text : Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            width: parent.width - 30
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: devMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }
}
