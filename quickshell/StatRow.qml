// A label/value pair. The value is monospace so columns of numbers line up
// down the panel instead of wandering.

import QtQuick

Item {
    id: root
    property string label: ""
    property string value: ""
    property color valueColor: Theme.text

    implicitHeight: 22
    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }
    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        color: root.valueColor
        font.family: Theme.monoFamily
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideLeft
        width: Math.min(implicitWidth, root.width * 0.62)
        horizontalAlignment: Text.AlignRight
    }
}
