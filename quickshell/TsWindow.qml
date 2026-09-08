// The Tailscale control surface -- a window, not a popout.
//
// THE DECISION, because this is the first one and it sets the pattern.
//
// A popout is a menu: 340px wide, anchored under the indicator that opened it,
// dismissed by looking away. That is right for a volume slider and wrong for a
// tailnet. Peers alone want four columns and an action per row, and exit nodes,
// Taildrop, preferences, serve/funnel, lock and certificates are still to
// come. Cramming them into a menu would produce something worse than either
// choice, so the indicator opens this and the popout keeps the state plus the
// two or three things worth reaching in one click.
//
// What "window" means here is a full-output overlay with the panel drawn inside
// it, exactly the shape Launcher.qml already uses. Not a toplevel: Quickshell
// does have FloatingWindow, but nothing in this shell has exercised it against
// 0.3.1 and making the first window a first use of an untested window type is
// two unknowns where one will do. If a later surface wants to be tiled or
// alt-tabbed to, that is the moment to find out, and it can change here without
// touching anything that reads Ts.
//
// One window for the session, not one per screen, for the reason Launcher gives
// -- it takes the keyboard, and there is only one keyboard. shell.qml owns the
// instance; the bar, which is per-screen, sets Ts.windowOpen.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
    id: root

    // wl-copy takes its text as an argument, so this needs no stdin plumbing.
    // wl-clipboard is in the image already -- neovim needs it on Wayland.
    function copy(value) {
        clipProc.command = ["wl-copy", value];
        clipProc.running = true;
    }

    Process {
        id: clipProc
        command: ["true"]
    }

    PanelWindow {
        id: win
        visible: Ts.windowOpen

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusiveZone: 0
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Ts.windowOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Dim the desktop behind, and dismiss on a click outside. Same surface
        // as the panel, so the panel can never end up behind its own catcher.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)

            MouseArea {
                anchors.fill: parent
                onClicked: Ts.hideWindow()
            }
        }

        // Escape closes. This has no text input to hang the key handler off, so
        // it gets its own focused Item -- without one, nothing in the window
        // holds active focus and the key goes nowhere.
        Item {
            anchors.fill: parent
            focus: Ts.windowOpen
            Keys.onEscapePressed: Ts.hideWindow()
        }

        Rectangle {
            id: box

            anchors.centerIn: parent
            width: Theme.windowWidth
            height: Math.min(Theme.windowMaxHeight, parent.height - Theme.gap * 4)

            radius: Theme.radius + 4
            color: Theme.mantle
            border.width: 1
            border.color: Theme.surface1

            // Swallow clicks so they do not reach the dimmer behind.
            MouseArea {
                anchors.fill: parent
            }

            // --- title -------------------------------------------------------
            Item {
                id: title
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 56

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.pad + 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.gap

                    Icon {
                        name: "tailscale"
                        size: 22
                        slash: !Ts.online
                        color: Ts.online ? (Ts.viaExitNode ? Theme.mauve : Theme.green) : Ts.needsLogin ? Theme.yellow : Theme.overlay0
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: "Tailscale"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: Ts.summary + (Ts.tailnet ? " -- " + Ts.tailnet : "")
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.pad + 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.gap

                    ActionButton {
                        visible: Ts.needsLogin
                        primary: true
                        label: "Log in"
                        onTriggered: Ts.login()
                    }
                    ActionButton {
                        visible: Ts.loggedIn
                        primary: !Ts.online
                        label: Ts.online ? "Disconnect" : "Connect"
                        onTriggered: Ts.online ? Ts.bringDown() : Ts.bringUp()
                    }
                    ActionButton {
                        label: "Close"
                        onTriggered: Ts.hideWindow()
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.surface0
                }
            }

            // --- body ---------------------------------------------------------
            Flickable {
                id: flick
                anchors.top: title.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.pad + 4
                clip: true

                contentWidth: width
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: body
                    width: flick.width
                    spacing: 4

                    // --- what the daemon says -------------------------------
                    Repeater {
                        model: Ts.health

                        Text {
                            required property string modelData
                            width: parent.width
                            text: modelData
                            color: Theme.yellow
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                        }
                    }

                    Text {
                        visible: Ts.lastMessage !== ""
                        width: parent.width
                        text: Ts.lastMessage
                        color: Theme.red
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    // --- logging in ------------------------------------------
                    //
                    // The image ships tailscale with no identity, so this is
                    // what a machine looks like on first boot. It is a state
                    // with one obvious action, not an error.
                    Column {
                        width: parent.width
                        spacing: 4
                        visible: Ts.needsLogin

                        Item {
                            width: parent.width
                            height: 6
                        }

                        Text {
                            text: "NOT LOGGED IN"
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            text: "This machine has no tailnet identity. Log in to join one."
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                        }

                        // The URL, when the daemon has one. Shown rather than
                        // opened: this shell binds no browser, and a button
                        // that silently does nothing is worse than a link you
                        // can copy.
                        Text {
                            visible: Ts.authUrl !== ""
                            width: parent.width
                            text: Ts.authUrl
                            color: Theme.accent
                            font.family: Theme.monoFamily
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WrapAnywhere
                        }

                        ActionButton {
                            visible: Ts.authUrl !== ""
                            label: "Copy login link"
                            onTriggered: root.copy(Ts.authUrl)
                        }
                    }

                    // --- this machine ----------------------------------------
                    Item {
                        width: parent.width
                        height: 10
                    }

                    Text {
                        text: "THIS MACHINE"
                        color: Theme.overlay0
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        font.weight: Font.DemiBold
                    }

                    StatRow {
                        label: "Status"
                        value: Ts.summary
                        valueColor: Ts.online ? Theme.green : Ts.needsLogin ? Theme.yellow : Theme.overlay0
                    }
                    StatRow {
                        label: "Machine"
                        value: Ts.selfNode ? Ts.selfNode.host : "-"
                    }
                    StatRow {
                        label: "Address"
                        value: Ts.selfNode ? Ts.selfNode.ip : "-"
                    }
                    StatRow {
                        label: "MagicDNS name"
                        value: Ts.selfNode ? Ts.selfNode.dns : "-"
                    }
                    StatRow {
                        label: "Tailnet"
                        value: Ts.tailnet || "-"
                    }
                    StatRow {
                        label: "Version"
                        value: Ts.tsVersion || "-"
                    }

                    // --- accounts ---------------------------------------------
                    //
                    // Hidden when tailscale only knows one, which is the normal
                    // case. A switcher offering the account you are already on
                    // is a row that does nothing.
                    Item {
                        width: parent.width
                        height: 10
                        visible: Ts.accounts.length > 1 || Ts.loggedIn
                    }

                    Text {
                        visible: Ts.accounts.length > 1 || Ts.loggedIn
                        text: "ACCOUNT"
                        color: Theme.overlay0
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        font.weight: Font.DemiBold
                    }

                    Repeater {
                        model: Ts.accounts.length > 1 ? Ts.accounts : []

                        Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 30
                            radius: Theme.radius
                            color: modelData.current ? Theme.surface0 : acctMouse.containsMouse ? Theme.surface0 : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.gap

                                // Faded rather than hidden: a Row closes up
                                // around an invisible child, so hiding the tick
                                // would indent every row except the current one.
                                Icon {
                                    name: "check"
                                    size: 13
                                    opacity: modelData.current ? 1 : 0
                                    color: Theme.green
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.account
                                    color: modelData.current ? Theme.text : Theme.subtext
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.tailnet
                                color: Theme.overlay0
                                font.family: Theme.monoFamily
                                font.pixelSize: 10
                            }

                            MouseArea {
                                id: acctMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !modelData.current
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Ts.switchAccount(modelData.account)
                            }
                        }
                    }

                    ActionButton {
                        visible: Ts.loggedIn
                        danger: true
                        label: "Log out"
                        onTriggered: Ts.logout()
                    }

                    // --- exit nodes -------------------------------------------
                    //
                    // Read from the peer list rather than from `exit-node list`:
                    // status --json already says which peers offer to be one,
                    // and a second process would be a second thing to keep in
                    // step with the first.
                    Item {
                        width: parent.width
                        height: 10
                        visible: Ts.loggedIn
                    }

                    Text {
                        visible: Ts.loggedIn
                        text: "EXIT NODE"
                        color: Theme.overlay0
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        font.weight: Font.DemiBold
                    }

                    Text {
                        visible: Ts.loggedIn && Ts.exitNodeOptions.length === 0
                        width: parent.width
                        text: "No machine on this tailnet is offering to be an exit node."
                        color: Theme.overlay0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        visible: Ts.loggedIn && Ts.exitNodeOptions.length > 0
                        width: parent.width
                        height: 30
                        radius: Theme.radius
                        color: !Ts.viaExitNode ? Theme.surface0 : noneMouse.containsMouse ? Theme.surface0 : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.gap

                            Icon {
                                name: "check"
                                size: 13
                                opacity: Ts.viaExitNode ? 0 : 1
                                color: Theme.green
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "None -- traffic leaves from here"
                                color: !Ts.viaExitNode ? Theme.text : Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: noneMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: Ts.viaExitNode
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Ts.clearExitNode()
                        }
                    }

                    Repeater {
                        model: Ts.loggedIn ? Ts.exitNodeOptions : []

                        Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 30
                            radius: Theme.radius
                            color: modelData.isExit ? Theme.surface0 : exitMouse.containsMouse ? Theme.surface0 : "transparent"
                            opacity: modelData.online ? 1 : 0.5

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.gap

                                Icon {
                                    name: "check"
                                    size: 13
                                    opacity: modelData.isExit ? 1 : 0
                                    color: Theme.mauve
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.host
                                    color: modelData.isExit ? Theme.text : Theme.subtext
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.online ? modelData.ip : "offline"
                                color: Theme.overlay0
                                font.family: Theme.monoFamily
                                font.pixelSize: 10
                            }

                            MouseArea {
                                id: exitMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: modelData.online && !modelData.isExit
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Ts.setExitNode(modelData.ip)
                            }
                        }
                    }

                    // --- peers -------------------------------------------------
                    Item {
                        width: parent.width
                        height: 10
                        visible: Ts.loggedIn
                    }

                    Text {
                        visible: Ts.loggedIn
                        text: "PEERS"
                        color: Theme.overlay0
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        font.weight: Font.DemiBold
                    }

                    Text {
                        visible: Ts.loggedIn && Ts.peers.length === 0
                        text: "No other machines on this tailnet."
                        color: Theme.overlay0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Repeater {
                        model: Ts.loggedIn ? Ts.peers : []

                        Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 40
                            radius: Theme.radius
                            color: peerMouse.containsMouse ? Theme.surface0 : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.right: peerActions.left
                                anchors.rightMargin: Theme.gap
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.gap

                                // Online is the first thing anyone wants from a
                                // peer list, so it is a filled dot rather than a
                                // word: it reads down the column at a glance.
                                Icon {
                                    name: "dot"
                                    size: 10
                                    color: modelData.online ? Theme.green : Theme.overlay0
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        text: modelData.host
                                        color: modelData.online ? Theme.text : Theme.subtext
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                    Text {
                                        text: modelData.ip + "  " + modelData.os
                                        color: Theme.overlay0
                                        font.family: Theme.monoFamily
                                        font.pixelSize: 9
                                    }
                                }
                            }

                            Row {
                                id: peerActions
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.gap

                                // Direct or relayed is the first thing worth
                                // knowing about a slow peer, and `ping` is what
                                // answers it. The result replaces the label so
                                // the answer lands where the question was asked.
                                Text {
                                    visible: Ts.pingTarget === modelData.ip
                                    text: Ts.pingResult
                                    color: Theme.subtext
                                    font.family: Theme.monoFamily
                                    font.pixelSize: 9
                                    elide: Text.ElideLeft
                                    width: Math.min(implicitWidth, 300)
                                    horizontalAlignment: Text.AlignRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    visible: Ts.pingTarget !== modelData.ip && modelData.online
                                    text: modelData.direct ? "direct" : modelData.relay ? "relay " + modelData.relay : "-"
                                    color: modelData.direct ? Theme.green : Theme.yellow
                                    font.family: Theme.monoFamily
                                    font.pixelSize: 9
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                ActionButton {
                                    label: "Ping"
                                    enabled: modelData.online
                                    anchors.verticalCenter: parent.verticalCenter
                                    onTriggered: Ts.ping(modelData.ip)
                                }
                            }

                            MouseArea {
                                id: peerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                // Hover only. The row itself does nothing yet;
                                // "SSH to this node" lands with the rest of the
                                // SSH work.
                                acceptedButtons: Qt.NoButton
                            }
                        }
                    }

                    // --- diagnostics ---------------------------------------------
                    //
                    // `status` and `netcheck` explain a bad connection better
                    // than this panel could infer from the same data, so their
                    // output is shown as they wrote it. Run on request, never on
                    // a timer: netcheck sends real probes to DERP servers.
                    Item {
                        width: parent.width
                        height: 10
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.gap

                        Text {
                            text: "DIAGNOSTICS"
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        ActionButton {
                            label: "Run"
                            anchors.verticalCenter: parent.verticalCenter
                            onTriggered: Ts.runDiagnostics()
                        }
                    }

                    Text {
                        visible: Ts.diagText !== ""
                        width: parent.width
                        text: Ts.diagText
                        color: Theme.subtext
                        font.family: Theme.monoFamily
                        font.pixelSize: 9
                        wrapMode: Text.Wrap
                    }

                    Item {
                        width: parent.width
                        height: Theme.pad
                    }
                }
            }
        }
    }
}
