// The bar, and the popout that belongs to it.
//
// Both windows live here because the popout has to position itself under
// whichever indicator was clicked, and that is a fact only the bar knows. One
// popout is reused for every panel rather than one window per indicator:
// switching content is instant, and there is only ever one thing on screen.

import Quickshell
import Quickshell.Wayland
import QtQuick

Scope {
    id: root

    required property var modelData

    // Which panel is open, and where its indicator sat. Empty means closed.
    property string active: ""
    property real anchorFromRight: 0

    function toggle(name, fromRight) {
        if (root.active === name) {
            root.active = "";
        } else {
            root.active = name;
            root.anchorFromRight = fromRight;
        }
    }

    PanelWindow {
        id: bar
        screen: root.modelData

        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: Theme.barHeight
        color: Theme.base

        // A hairline under the bar. Without it the bar and a maximised dark
        // window merge into one shape and the bar stops reading as a surface.
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.surface0
        }

        // --- left: workspaces ---------------------------------------------
        Workspaces {
            anchors.left: parent.left
            anchors.leftMargin: Theme.pad
            anchors.verticalCenter: parent.verticalCenter
        }

        // --- centre: clock, which opens the calendar ------------------------
        Indicator {
            id: clockInd
            anchors.centerIn: parent
            name: "calendar"
            active: root.active === "calendar"
            onActivated: root.toggle("calendar", bar.width - (x + width / 2))

            content: Clock {}
        }

        // --- right: indicators ---------------------------------------------
        Row {
            id: tray
            anchors.right: parent.right
            anchors.rightMargin: Theme.gap
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            // Other applications' tray icons, kept visually separate from ours.
            SysTray {
                anchors.verticalCenter: parent.verticalCenter
            }

            Indicator {
                id: netInd
                name: "net"
                active: root.active === "net"
                onActivated: root.toggle("net", bar.width - (tray.x + x + width / 2))

                content: Row {
                    spacing: 6
                    Icon {
                        name: Net.kind === "wifi" ? "wifi" : "ethernet"
                        size: Theme.iconSize
                        level: Net.wifiBars
                        slash: !Net.online
                        color: Net.online ? Theme.text : Theme.red
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    // A VPN badge rather than a separate indicator: it is a
                    // property of the connection, not a peer of it.
                    Icon {
                        visible: Net.tunnels.length > 0
                        name: "vpn"
                        size: 13
                        color: Theme.mauve
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Indicator {
                id: btInd
                name: "bt"
                visible: Bt.available
                active: root.active === "bt"
                onActivated: root.toggle("bt", bar.width - (tray.x + x + width / 2))

                content: Icon {
                    name: "bluetooth"
                    size: Theme.iconSize
                    slash: !Bt.powered
                    color: Bt.powered ? (Bt.devices.length > 0 ? Theme.accent : Theme.text) : Theme.overlay0
                }
            }

            Indicator {
                id: audioInd
                name: "audio"
                active: root.active === "audio"
                onActivated: root.toggle("audio", bar.width - (tray.x + x + width / 2))
                onScrolled: delta => Audio.setVolume(Audio.volume + delta * 5)
                onMiddleClicked: Audio.toggleMute()

                content: Row {
                    spacing: 6
                    Icon {
                        name: "volume"
                        size: Theme.iconSize
                        level: Audio.level
                        slash: Audio.muted
                        color: Audio.muted ? Theme.red : Theme.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: Audio.muted ? "--" : Audio.volume + "%"
                        color: Theme.subtext
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Indicator {
                id: dispInd
                name: "display"
                active: root.active === "display"
                onActivated: root.toggle("display", bar.width - (tray.x + x + width / 2))

                content: Icon {
                    name: "display"
                    size: Theme.iconSize
                    color: Theme.text
                }
            }

            Indicator {
                id: notifInd
                name: "notifs"
                active: root.active === "notifs"
                onActivated: root.toggle("notifs", bar.width - (tray.x + x + width / 2))
                onMiddleClicked: Notifs.clearAll()

                content: Item {
                    implicitWidth: bell.width
                    implicitHeight: bell.height

                    Icon {
                        id: bell
                        name: "bell"
                        size: Theme.iconSize
                        color: Notifs.count > 0 ? Theme.text : Theme.overlay0
                    }

                    // A count, not a dot: "three waiting" and "one waiting" are
                    // different decisions about whether to look now.
                    Rectangle {
                        visible: Notifs.count > 0
                        // Sits off the icon's corner rather than on it, with a
                        // ring in the bar's own colour so the two shapes read as
                        // separate. Overlapping the bell directly ate the top
                        // right of the glyph and made both harder to read.
                        anchors.right: parent.right
                        anchors.rightMargin: -6
                        anchors.top: parent.top
                        anchors.topMargin: -5
                        width: Math.max(13, badge.implicitWidth + 6)
                        height: 13
                        radius: 6.5
                        color: Theme.red
                        border.width: 2
                        border.color: Theme.base

                        Text {
                            id: badge
                            anchors.centerIn: parent
                            text: Notifs.count > 9 ? "9+" : Notifs.count
                            color: Theme.base
                            font.family: Theme.monoFamily
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            Indicator {
                id: sysInd
                name: "sys"
                active: root.active === "sys"
                onActivated: root.toggle("sys", bar.width - (tray.x + x + width / 2))

                content: Row {
                    spacing: 6
                    Icon {
                        name: "cpu"
                        size: Theme.iconSize
                        // Amber and red at the same thresholds the gauges use,
                        // so the bar and the panel never disagree about whether
                        // something is worth looking at.
                        color: Sys.cpuPercent >= 90 ? Theme.red : Sys.cpuPercent >= 70 ? Theme.yellow : Theme.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: Sys.cpuPercent + "%"
                        color: Theme.subtext
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Indicator {
                id: powerInd
                name: "power"
                active: root.active === "power"
                onActivated: root.toggle("power", bar.width - (tray.x + x + width / 2))

                content: Icon {
                    name: "power"
                    size: Theme.iconSize
                    color: root.active === "power" ? Theme.red : Theme.text
                }
            }
        }
    }

    // --- the popout --------------------------------------------------------
    //
    // Full screen and transparent, with the panel drawn inside it. That is what
    // makes clicking anywhere else dismiss it, without a second window and
    // without guessing at layer stacking order -- the catcher and the panel are
    // the same surface, so the panel can never end up behind its own catcher.
    //
    // The cost is that this takes pointer input across the whole output while
    // open. For a menu that is the intended behaviour, and it is the same
    // trade every desktop makes for an open menu.
    PanelWindow {
        id: popout
        screen: root.modelData
        visible: root.active !== ""

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Must not reserve space, or opening a menu would shove every window on
        // the desktop sideways.
        exclusiveZone: 0
        color: "transparent"

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.active = ""
        }

        Rectangle {
            id: panel

            // Just a gap from the top -- NOT barHeight plus a gap. This window
            // is anchored to the full output but still respects the bar's
            // exclusive zone, so it already begins below the bar. Adding the
            // bar's height again put the panel a bar's-worth too low.
            //
            // Centred on the indicator that opened it, and clamped so it never
            // hangs off either edge.
            y: Theme.gap
            x: Math.max(Theme.gap, Math.min(parent.width - width - Theme.gap, parent.width - root.anchorFromRight - width / 2))

            width: Theme.popoutWidth
            height: Math.min(Theme.popoutMaxHeight, body.implicitHeight + Theme.pad * 2)

            radius: Theme.radius + 2
            color: Theme.mantle
            border.width: 1
            border.color: Theme.surface0

            // Clicks on the panel itself must not fall through to the catcher.
            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: body
                anchors.fill: parent
                anchors.margins: Theme.pad
                spacing: 0

                Loader {
                    width: parent.width
                    active: root.active !== ""
                    sourceComponent: root.active === "net" ? netPanel : root.active === "bt" ? btPanel : root.active === "audio" ? audioPanel : root.active === "display" ? displayPanel : root.active === "sys" ? sysPanel : root.active === "notifs" ? notifPanel : root.active === "calendar" ? calendarPanel : root.active === "power" ? powerPanel : null
                }
            }
        }
    }

    Component {
        id: netPanel
        NetPanel {}
    }
    Component {
        id: btPanel
        BtPanel {}
    }
    Component {
        id: audioPanel
        AudioPanel {}
    }
    Component {
        id: displayPanel
        DisplayPanel {}
    }
    Component {
        id: sysPanel
        SysPanel {}
    }
    Component {
        id: notifPanel
        NotifPanel {}
    }
    Component {
        id: calendarPanel
        CalendarPanel {}
    }
    Component {
        id: powerPanel
        PowerPanel {}
    }
}
