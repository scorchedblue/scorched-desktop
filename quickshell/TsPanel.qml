// Tailscale popout: the state, and the few things worth reaching in one click.
//
// Everything else lives in TsWindow.qml. This deliberately stays the same shape
// as every other popout in the bar -- the moment it starts carrying a peer list
// it stops being one, which is the whole reason the window exists.

import QtQuick

Column {
    spacing: 4

    PanelHeader {
        title: "Tailscale"
        subtitle: Ts.summary + (Ts.tailnet ? " -- " + Ts.tailnet : "")

        // The switch is connect/disconnect, not log in/out. Logging out is a
        // decision about identity and lives in the window with a confirmation
        // shape around it; this is the one people flip several times a day.
        trailing: Switch {
            checked: Ts.online
            enabled: Ts.loggedIn
            opacity: Ts.loggedIn ? 1 : 0.4
            onToggled: value => value ? Ts.bringUp() : Ts.bringDown()
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    StatRow {
        label: "Status"
        value: Ts.summary
        valueColor: Ts.online ? Theme.green : Ts.needsLogin ? Theme.yellow : Theme.overlay0
    }
    StatRow {
        label: "Address"
        value: Ts.selfNode ? Ts.selfNode.ip : "-"
    }
    StatRow {
        label: "Machine"
        value: Ts.selfNode ? Ts.selfNode.host : "-"
    }
    StatRow {
        visible: Ts.viaExitNode
        label: "Exit node"
        value: Ts.viaExitNode ? Ts.exitNode.host : "-"
        valueColor: Theme.mauve
    }
    StatRow {
        label: "Peers"
        value: Ts.peers.length > 0 ? Ts.peers.filter(p => p.online).length + " of " + Ts.peers.length + " online" : "-"
    }

    // What the daemon says is wrong, and what the last command said. Both are
    // shown here rather than only in the window: a popout that hides the reason
    // a click did nothing is worse than one that never had the click.
    Item {
        width: parent.width
        height: 6
        visible: Ts.health.length > 0 || Ts.lastMessage !== ""
    }

    Repeater {
        model: Ts.health

        Text {
            required property string modelData
            width: parent.width
            text: modelData
            color: Theme.yellow
            font.family: Theme.fontFamily
            font.pixelSize: 10
            wrapMode: Text.Wrap
        }
    }

    Text {
        visible: Ts.lastMessage !== ""
        width: parent.width
        text: Ts.lastMessage
        color: Theme.red
        font.family: Theme.monoFamily
        font.pixelSize: 10
        wrapMode: Text.Wrap
    }

    Item {
        width: parent.width
        height: 6
    }

    Row {
        width: parent.width
        spacing: Theme.gap

        ActionButton {
            visible: Ts.needsLogin
            primary: true
            label: "Log in"
            onTriggered: Ts.login()
        }

        ActionButton {
            visible: Ts.viaExitNode
            label: "Clear exit node"
            onTriggered: Ts.clearExitNode()
        }

        ActionButton {
            primary: !Ts.needsLogin
            label: "Open Tailscale"
            onTriggered: Ts.showWindow()
        }
    }
}
