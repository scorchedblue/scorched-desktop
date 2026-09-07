// A pill toggle. Small, obvious, and the only on/off control in the shell, so
// on/off always looks the same wherever it appears.

import QtQuick

Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 38
    implicitHeight: 20
    radius: height / 2
    color: checked ? Theme.accent : Theme.surface1

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }

    Rectangle {
        width: 14
        height: 14
        radius: 7
        color: root.checked ? Theme.base : Theme.subtext
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 3 : 3

        Behavior on x {
            NumberAnimation {
                duration: Theme.anim
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
