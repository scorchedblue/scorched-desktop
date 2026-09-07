// A labelled percentage bar. The workhorse of the system panel.
//
// Colour tracks severity so a glance is enough: green until it matters, amber
// when it is worth knowing, red when it is worth acting on.

import QtQuick

Item {
    id: root

    property string label: ""
    property int percent: 0
    property string detail: ""
    property string iconName: ""

    implicitHeight: 34

    Row {
        id: head
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 6

        Icon {
            name: root.iconName
            size: 13
            color: Theme.subtext
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconName !== ""
        }
        Text {
            text: root.label
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        text: root.detail
        color: Theme.overlay0
        font.family: Theme.monoFamily
        font.pixelSize: 10
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        height: 5
        radius: 2.5
        color: Theme.surface1

        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, root.percent)) / 100
            height: parent.height
            radius: parent.radius
            color: root.percent >= 90 ? Theme.red : root.percent >= 70 ? Theme.yellow : Theme.green

            Behavior on width {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.anim
                }
            }
        }
    }
}
