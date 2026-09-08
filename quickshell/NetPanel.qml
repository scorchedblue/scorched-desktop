// Network popout.
//
// Leads with the link the user is actually on, then tunnels, then nearby
// networks if this is wifi. Tunnels get their own section because a VPN being
// up is a fact people need at a glance and a "connected" badge hides it.

import QtQuick

Column {
    spacing: 4

    PanelHeader {
        title: Net.kind === "none" ? "Offline" : Net.connection
        subtitle: Net.kind === "none" ? "No active connection" : (Net.kind === "wifi" ? "Wi-Fi on " + Net.device : "Ethernet on " + Net.device)

        trailing: Icon {
            name: Net.kind === "wifi" ? "wifi" : "ethernet"
            size: 20
            level: Net.wifiBars
            slash: Net.kind === "none"
            color: Net.kind === "none" ? Theme.overlay0 : Net.connecting || Net.noRoute ? Theme.yellow : Theme.green
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    StatRow {
        label: "Status"
        value: Net.online ? (Net.noRoute ? "Connected, no route" : "Connected") : Net.connecting ? "Connecting" : "Disconnected"
        valueColor: Net.online ? (Net.noRoute ? Theme.yellow : Theme.green) : Net.connecting ? Theme.yellow : Theme.red
    }
    StatRow {
        label: "Interface"
        value: Net.device || "-"
    }
    StatRow {
        label: "IPv4"
        value: Net.ipv4 || "-"
    }
    StatRow {
        label: "Gateway"
        value: Net.gateway || "-"
    }
    StatRow {
        visible: Net.kind === "wifi"
        label: "Signal"
        value: Net.wifiSignal + "%"
        valueColor: Net.wifiSignal >= 50 ? Theme.green : Net.wifiSignal >= 25 ? Theme.yellow : Theme.red
    }

    // --- tunnels ----------------------------------------------------------
    Item {
        width: parent.width
        height: 10
        visible: Net.tunnels.length > 0
    }

    Text {
        visible: Net.tunnels.length > 0
        text: "TUNNELS"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.letterSpacing: 1
        font.weight: Font.DemiBold
    }

    Repeater {
        model: Net.tunnels

        Row {
            required property var modelData
            width: parent.width
            spacing: 8
            height: 24

            Icon {
                name: "vpn"
                size: 14
                color: Theme.mauve
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: modelData.name
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: modelData.type
                color: Theme.overlay0
                font.family: Theme.monoFamily
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // --- nearby wifi ------------------------------------------------------
    Item {
        width: parent.width
        height: 10
        visible: Net.kind === "wifi" && Net.wifiNetworks.length > 0
    }

    Text {
        visible: Net.kind === "wifi" && Net.wifiNetworks.length > 0
        text: "NEARBY"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.letterSpacing: 1
        font.weight: Font.DemiBold
    }

    Repeater {
        model: Net.kind === "wifi" ? Net.wifiNetworks : []

        Rectangle {
            required property var modelData
            width: parent.width
            height: 26
            radius: Theme.radius
            color: wifiMouse.containsMouse ? Theme.surface0 : "transparent"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Icon {
                    name: "wifi"
                    size: 13
                    level: modelData.signal >= 75 ? 3 : modelData.signal >= 50 ? 2 : modelData.signal >= 25 ? 1 : 0
                    color: modelData.active ? Theme.green : Theme.subtext
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: modelData.ssid
                    color: modelData.active ? Theme.text : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.signal + "%"
                color: Theme.overlay0
                font.family: Theme.monoFamily
                font.pixelSize: 10
            }

            MouseArea {
                id: wifiMouse
                anchors.fill: parent
                hoverEnabled: true
            }
        }
    }
}
