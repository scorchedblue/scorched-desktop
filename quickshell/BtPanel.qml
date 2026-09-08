// Bluetooth popout: power toggle, adapter identity, connected devices.
//
// Pairing is deliberately absent. It is a multi-step, failure-prone flow that
// wants a real dialog, and a half-built pairing UI is worse than sending people
// to a tool that does it properly.

import QtQuick

Column {
    id: root
    spacing: 4

    // Keyboard cursor into this panel's actions, driven by Bar.qml. Index 0
    // is the power switch; the rest are the connected devices, in the order
    // Bt.devices lists them.
    property int focusIndex: -1
    readonly property int actionCount: Bt.available ? 1 + (Bt.powered ? Bt.devices.length : 0) : 0

    function activate(index) {
        if (index === 0) {
            Bt.setPowered(!Bt.powered);
            return;
        }
        const dev = Bt.devices[index - 1];
        if (dev)
            Bt.disconnect(dev.mac);
    }

    PanelHeader {
        title: "Bluetooth"
        subtitle: !Bt.available ? "No controller" : !Bt.powered ? "Off" : Bt.devices.length > 0 ? Bt.devices.length + " connected" : Bt.connecting ? "Connecting..." : "On, nothing connected"

        trailing: Switch {
            checked: Bt.powered
            enabled: Bt.available
            opacity: Bt.available ? 1 : 0.4
            focused: root.focusIndex === 0
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
            required property int index
            readonly property bool focused: root.focusIndex === index + 1

            width: parent.width
            height: 30
            radius: Theme.radius
            color: focused || devMouse.containsMouse ? Theme.surface0 : "transparent"
            border.width: focused ? 2 : 0
            border.color: Theme.accent

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
