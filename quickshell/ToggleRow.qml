// A labelled switch with an optional right-hand detail. Used wherever a setting
// is on or off, so every one of them looks and behaves the same.

import QtQuick

Item {
    id: root

    property string label: ""
    property string detail: ""
    property bool checked: false
    signal toggled(bool value)

    implicitHeight: 30

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    Text {
        anchors.right: sw.left
        anchors.rightMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        text: root.detail
        color: Theme.overlay0
        font.family: Theme.monoFamily
        font.pixelSize: 10
    }

    Switch {
        id: sw
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checked: root.checked
        onToggled: value => root.toggled(value)
    }
}
