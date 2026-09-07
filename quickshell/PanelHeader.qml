// Title row at the top of every popout panel, with an optional right-hand slot
// for a primary toggle. Uniform across panels so the eye learns one shape.

import QtQuick

Item {
    id: root
    property string title: ""
    property string subtitle: ""
    property alias trailing: slot.data

    implicitHeight: 40
    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            text: root.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.DemiBold
        }
        Text {
            text: root.subtitle
            visible: text !== ""
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            width: root.width - slot.width - Theme.gap
        }
    }

    Row {
        id: slot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap
    }
}
