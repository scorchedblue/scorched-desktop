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

    // Popout state lives in Popouts, not here -- a keybinding has to be able
    // to open one without knowing which screen's Bar it should belong to.
    // This is just whether the currently-open popout belongs to this screen.
    readonly property bool popoutHere: Popouts.active !== "" && Popouts.anchorScreen === root.modelData

    // Keyboard navigation inside whichever panel is loaded. The panel itself
    // knows its own action count and what each one does; this only knows how
    // to move a cursor through them and ask the panel to act.
    function moveFocus(delta) {
        const item = popoutLoader.item;
        const n = item && item.actionCount ? item.actionCount : 0;
        if (n <= 0)
            return;
        if (Popouts.focusIndex < 0)
            Popouts.focusIndex = delta > 0 ? 0 : n - 1;
        else
            Popouts.focusIndex = (Popouts.focusIndex + delta + n) % n;
    }

    function activateFocus() {
        const item = popoutLoader.item;
        if (item && item.activate && Popouts.focusIndex >= 0)
            item.activate(Popouts.focusIndex);
    }

    function adjustFocus(delta) {
        const item = popoutLoader.item;
        if (item && item.adjust && Popouts.focusIndex >= 0)
            item.adjust(Popouts.focusIndex, delta);
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
            active: Popouts.active === "calendar" && Popouts.anchorScreen === root.modelData
            onActivated: Popouts.toggle("calendar", bar.width - (x + width / 2), root.modelData)

            content: Clock {}
        }

        // --- right: indicators ---------------------------------------------
        Row {
            id: tray
            anchors.right: parent.right
            anchors.rightMargin: Theme.gap
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.indicatorSpacing

            // Other applications' tray icons, kept visually separate from ours.
            SysTray {
                anchors.verticalCenter: parent.verticalCenter
            }

            Indicator {
                id: netInd
                name: "net"
                active: Popouts.active === "net" && Popouts.anchorScreen === root.modelData
                onActivated: Popouts.toggle("net", bar.width - (tray.x + x + width / 2), root.modelData)

                content: Item {
                    implicitWidth: netIcon.width
                    implicitHeight: netIcon.height

                    Icon {
                        id: netIcon
                        name: Net.kind === "wifi" ? "wifi" : "ethernet"
                        size: Theme.iconSize
                        level: Net.wifiBars
                        // No link at all is the only case that reads as "off";
                        // connecting and up-without-a-route both have a link,
                        // just not a working one yet.
                        slash: Net.kind === "none"
                        color: Net.kind === "none" ? Theme.red : Net.connecting || Net.noRoute ? Theme.yellow : Theme.text
                    }

                    // A VPN badge rather than a separate indicator: it is a
                    // property of the connection, not a peer of it.
                    Badge {
                        visible: Net.tunnels.length > 0
                        iconName: "vpn"
                        color: Theme.mauve
                    }
                }
            }

            Indicator {
                id: btInd
                name: "bt"
                visible: Bt.available
                active: Popouts.active === "bt" && Popouts.anchorScreen === root.modelData
                onActivated: Popouts.toggle("bt", bar.width - (tray.x + x + width / 2), root.modelData)

                content: Icon {
                    name: "bluetooth"
                    size: Theme.iconSize
                    slash: !Bt.powered
                    // Off, connected, connecting, on-with-nothing-paired -- in
                    // that priority order, since a live connection outranks a
                    // pending one and a pending one outranks idle.
                    color: !Bt.powered ? Theme.overlay0 : Bt.devices.length > 0 ? Theme.accent : Bt.connecting ? Theme.yellow : Theme.text
                }
            }

            Indicator {
                id: audioInd
                name: "audio"
                active: Popouts.active === "audio" && Popouts.anchorScreen === root.modelData
                onActivated: Popouts.toggle("audio", bar.width - (tray.x + x + width / 2), root.modelData)
                onScrolled: delta => Audio.setVolume(Audio.volume + delta * 5)
                onMiddleClicked: Audio.toggleMute()

                content: Row {
                    spacing: Theme.contentSpacing
                    Icon {
                        name: "volume"
                        size: Theme.iconSize
                        level: Audio.level
                        slash: !Audio.hasSink || Audio.muted
                        color: !Audio.hasSink ? Theme.overlay0 : Audio.muted ? Theme.red : Theme.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: !Audio.hasSink || Audio.muted ? "--" : Audio.volume + "%"
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
                active: Popouts.active === "display" && Popouts.anchorScreen === root.modelData
                onActivated: Popouts.toggle("display", bar.width - (tray.x + x + width / 2), root.modelData)

                content: Icon {
                    name: "display"
                    size: Theme.iconSize
                    color: Theme.text
                }
            }

            Indicator {
                id: notifInd
                name: "notifs"
                active: Popouts.active === "notifs" && Popouts.anchorScreen === root.modelData
                onActivated: Popouts.toggle("notifs", bar.width - (tray.x + x + width / 2), root.modelData)
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
                    Badge {
                        visible: Notifs.count > 0
                        text: Notifs.count > 9 ? "9+" : String(Notifs.count)
                        color: Theme.red
                    }
                }
            }

            Indicator {
                id: aiInd
                name: "ai"
                // Hidden when no provider is configured, rather than showing a
                // permanent question mark on an account that never signs in.
                visible: AiUsage.available
                active: Popouts.active === "ai" && Popouts.anchorScreen === root.modelData
                onActivated: Popouts.toggle("ai", bar.width - (tray.x + x + width / 2), root.modelData)

                content: Row {
                    spacing: 6
                    Icon {
                        name: "sparkle"
                        size: Theme.iconSize
                        // Same thresholds as every other gauge in the shell, so
                        // the bar and the panel never disagree about whether
                        // something is worth looking at. Grey is "we do not
                        // know" and is deliberately not green.
                        color: AiUsage.locked ? Theme.red : AiUsage.sessionPercent < 0 ? Theme.overlay0 : AiUsage.sessionPercent >= 90 ? Theme.red : AiUsage.sessionPercent >= 70 ? Theme.yellow : Theme.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        // "?", never a number. Not knowing and being at zero
                        // are different facts, and only one of them means it is
                        // safe to start something long.
                        text: AiUsage.sessionPercent < 0 ? "?" : Math.round(AiUsage.sessionPercent) + "%"
                        color: Theme.subtext
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Indicator {
                id: sysInd
                name: "sys"
                active: Popouts.active === "sys" && Popouts.anchorScreen === root.modelData
                onActivated: Popouts.toggle("sys", bar.width - (tray.x + x + width / 2), root.modelData)

                content: Row {
                    spacing: Theme.contentSpacing
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
                active: Popouts.active === "power" && Popouts.anchorScreen === root.modelData
                onActivated: Popouts.toggle("power", bar.width - (tray.x + x + width / 2), root.modelData)

                content: Icon {
                    name: "power"
                    size: Theme.iconSize
                    color: Theme.text
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
        visible: root.popoutHere

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

        // Exclusive while open, same as the launcher: a popout that does not
        // take the keyboard cannot be navigated without a mouse, which is the
        // entire point of this window existing.
        WlrLayershell.keyboardFocus: root.popoutHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: Popouts.close()
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
            x: Math.max(Theme.gap, Math.min(parent.width - width - Theme.gap, parent.width - Popouts.anchorFromRight - width / 2))

            width: Theme.popoutWidth
            height: Math.min(Theme.popoutMaxHeight, body.implicitHeight + Theme.pad * 2)

            radius: Theme.radius + 2
            color: Theme.mantle
            border.width: 1
            border.color: Theme.surface0

            // Takes keyboard focus whenever this screen's popout is open, so
            // Escape, the arrow keys and Enter all reach here rather than
            // needing a click first. Un-handled keys bubble up from whatever
            // row inside the loaded panel actually has focus, so this is the
            // one place Escape needs to be handled at all.
            focus: root.popoutHere

            Keys.onEscapePressed: Popouts.close()
            Keys.onDownPressed: root.moveFocus(1)
            Keys.onUpPressed: root.moveFocus(-1)
            Keys.onReturnPressed: root.activateFocus()
            Keys.onEnterPressed: root.activateFocus()
            Keys.onSpacePressed: root.activateFocus()
            Keys.onLeftPressed: root.adjustFocus(-5)
            Keys.onRightPressed: root.adjustFocus(5)

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
                    id: popoutLoader
                    width: parent.width
                    active: root.popoutHere
                    sourceComponent: Popouts.active === "net" ? netPanel : Popouts.active === "bt" ? btPanel : Popouts.active === "audio" ? audioPanel : Popouts.active === "display" ? displayPanel : Popouts.active === "ai" ? aiPanel : Popouts.active === "sys" ? sysPanel : Popouts.active === "notifs" ? notifPanel : Popouts.active === "calendar" ? calendarPanel : Popouts.active === "power" ? powerPanel : null
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
        BtPanel {
            focusIndex: Popouts.focusIndex
        }
    }
    Component {
        id: audioPanel
        AudioPanel {
            focusIndex: Popouts.focusIndex
        }
    }
    Component {
        id: displayPanel
        DisplayPanel {
            focusIndex: Popouts.focusIndex
        }
    }
    Component {
        id: aiPanel
        AiPanel {}
    }
    Component {
        id: sysPanel
        SysPanel {}
    }
    Component {
        id: notifPanel
        NotifPanel {
            focusIndex: Popouts.focusIndex
        }
    }
    Component {
        id: calendarPanel
        CalendarPanel {
            focusIndex: Popouts.focusIndex
        }
    }
    Component {
        id: powerPanel
        PowerPanel {
            focusIndex: Popouts.focusIndex
        }
    }
}
