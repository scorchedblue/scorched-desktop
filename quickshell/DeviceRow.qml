// One selectable audio device. Used for both sinks and sources.

import QtQuick

Rectangle {
    id: root

    property string label: ""
    property bool selected: false
    signal picked

    height: 26
    radius: Theme.radius
    color: selected ? Theme.surface0 : devMouse.containsMouse ? Theme.surface0 : "transparent"

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
