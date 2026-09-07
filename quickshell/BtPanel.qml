// Bluetooth popout: power toggle, adapter identity, connected devices.
//
// Pairing is deliberately absent. It is a multi-step, failure-prone flow that
// wants a real dialog, and a half-built pairing UI is worse than sending people
// to a tool that does it properly.

import QtQuick

Column {
    spacing: 4

    PanelHeader {
        title: "Bluetooth"
        subtitle: !Bt.available ? "No controller" : Bt.powered ? (Bt.devices.length > 0 ? Bt.devices.length + " connected" : "On, nothing connected") : "Off"

        trailing: Switch {
            checked: Bt.powered
            enabled: Bt.available
            opacity: Bt.available ? 1 : 0.4
            onToggled: value => Bt.setPowered(value)
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    StatRow {
        label: "Adapter"
        value: Bt.adapterName || "-"
    }
    StatRow {
        label: "Power"
        value: Bt.powered ? "On" : "Off"
        valueColor: Bt.powered ? Theme.green : Theme.overlay0
    }

    Item {
        width: parent.width
        height: 10
        visible: Bt.powered
    }

    Text {
        visible: Bt.powered
        text: "DEVICES"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.letterSpacing: 1
        font.weight: Font.DemiBold
    }

    Text {
        visible: Bt.powered && Bt.devices.length === 0
        text: "Nothing connected"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    Repeater {
        model: Bt.powered ? Bt.devices : []

        Rectangle {
            required property var modelData
            width: parent.width
            height: 30
            radius: Theme.radius
            color: devMouse.containsMouse ? Theme.surface0 : "transparent"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Icon {
                    name: "bluetooth"
                    size: 13
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Text {
                        text: modelData.mac
                        color: Theme.overlay0
                        font.family: Theme.monoFamily
                        font.pixelSize: 9
                    }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: "Disconnect"
                visible: devMouse.containsMouse
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            MouseArea {
                id: devMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Bt.disconnect(modelData.mac)
            }
        }
    }
}
