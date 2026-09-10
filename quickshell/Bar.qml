// The bar, and the popout that belongs to it.
//
// Both windows live here because the popout has to position itself under
// whichever indicator was clicked, and that is a fact only the bar knows. One
// popout is reused for every panel rather than one window per indicator:
// switching content is instant, and there is only ever one thing on screen.
//
// The bar is not three anchored children any more. It is one ordered model --
// BarLayout, three lists of item ids -- rendered into three positioned zones,
// and every item is an entry in that model rather than a child that knows where
// it lives. That is what lets an item be dragged from one zone to another: the
// zones are positions, not separate widgets. Reading this file as though the
// items were still anchored will mislead you at every turn.
//
// A zone is still a *position*, not a bucket: the centre zone is centred on the
// bar itself, so a clock in it centres exactly as it did when it was the only
// thing with `anchors.centerIn`.

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

        // --- the strip ------------------------------------------------------
        //
        // Three positioned zones over one ordered model, and the drag gesture
        // that moves items between them.
        Item {
            id: strip
            anchors.fill: parent

            // What is being dragged and where it would land if the pointer were
            // released now. An empty dragId means no drag is in progress; an
            // empty dropBefore means the end of the zone.
            property string dragId: ""
            property string dropZone: ""
            property string dropBefore: ""
            property real dropX: 0

            function rowFor(zone) {
                return zone === "centre" ? centreRow : zone === "left" ? leftRow : rightRow;
            }

            function repeaterFor(zone) {
                return zone === "centre" ? centreRep : zone === "left" ? leftRep : rightRep;
            }

            // Distance from the bar's right edge to an item's centre, which is
            // what the popout anchors on. Measured through the scene rather than
            // from `x`, because an item's `x` is now relative to whichever zone
            // row it happens to be in, and it can be in any of them.
            function fromRight(item) {
                return bar.width - strip.mapFromItem(item, item.width / 2, 0).x;
            }

            // Which zone a pointer at `x` is over. Not thirds of the width: the
            // zones are three rows with empty bar between them, so a boundary is
            // the middle of a gap. An item let go in the space right of the
            // workspaces joins whichever row it was nearer, and an empty zone --
            // a centre with nothing in it is a zero-width row at the bar's
            // centre -- still has a neighbourhood to be dropped into, which is
            // what makes an emptied zone recoverable.
            function zoneAt(x) {
                const leftEdge = (leftRow.x + leftRow.width + centreRow.x) / 2;
                const rightEdge = (centreRow.x + centreRow.width + rightRow.x) / 2;
                return x < leftEdge ? "left" : x < rightEdge ? "centre" : "right";
            }

            // A zone's entries in model order, minus the one being dragged and
            // minus anything collapsed. Asked of the Repeater rather than read
            // off the row's children: the row's children are the delegates *and*
            // the Repeater itself, and a positioner is under no obligation to
            // hand them back in the order it drew them.
            function entriesOf(zone, exceptId) {
                const rep = strip.repeaterFor(zone);
                const out = [];
                for (let i = 0; i < rep.count; i++) {
                    const e = rep.itemAt(i);
                    if (e && e.visible && e.itemId !== exceptId)
                        out.push(e);
                }
                return out;
            }

            // Which item a drop at `x` would land in front of, or "" for the end
            // of the zone. An id, not a position: a zone's list can hold items
            // that are collapsed -- Bluetooth on a machine with no adapter -- and
            // counting only the visible ones would put the dropped item on the
            // wrong side of every hidden one before it.
            function dropBeforeAt(zone, x, exceptId) {
                const row = strip.rowFor(zone);
                for (const e of strip.entriesOf(zone, exceptId))
                    if (x <= strip.mapFromItem(row, e.x + e.width / 2, 0).x)
                        return e.itemId;
                return "";
            }

            function caretAt(zone, beforeId, exceptId) {
                const row = strip.rowFor(zone);
                const entries = strip.entriesOf(zone, exceptId);
                if (entries.length === 0)
                    return strip.mapFromItem(row, 0, 0).x;
                for (const e of entries)
                    if (e.itemId === beforeId)
                        return strip.mapFromItem(row, e.x, 0).x;
                const last = entries[entries.length - 1];
                return strip.mapFromItem(row, last.x + last.width, 0).x;
            }

            function dragMove(id, sceneX) {
                const x = strip.mapFromItem(null, sceneX, 0).x;
                const zone = strip.zoneAt(x);
                strip.dragId = id;
                strip.dropZone = zone;
                strip.dropBefore = strip.dropBeforeAt(zone, x, id);
                strip.dropX = strip.caretAt(zone, strip.dropBefore, id);
            }

            function dragEnd() {
                if (strip.dragId !== "")
                    BarLayout.place(strip.dragId, strip.dropZone, strip.dropBefore);
                strip.dragId = "";
            }

            function componentFor(id) {
                switch (id) {
                case "workspaces":
                    return workspacesItem;
                case "clock":
                    return clockItem;
                case "tray":
                    return trayItem;
                case "net":
                    return netItem;
                case "ts":
                    return tsItem;
                case "bt":
                    return btItem;
                case "audio":
                    return audioItem;
                case "display":
                    return displayItem;
                case "notifs":
                    return notifsItem;
                case "ai":
                    return aiItem;
                case "sys":
                    return sysItem;
                case "power":
                    return powerItem;
                }
                return null;
            }

            // --- the zones ----------------------------------------------------
            //
            // Positions, not buckets. Left and right keep the margins the
            // anchored layouts used; the centre is centred on the bar, so an
            // item in it is centred on the bar however wide its neighbours grow.
            //
            // The row holding the dragged item is raised, because the item is
            // dragged *across* the others: without this it would slide under the
            // rows declared after it, and a cross-zone drag is exactly the case
            // this whole change exists for.
            Row {
                id: leftRow
                anchors.left: parent.left
                anchors.leftMargin: Theme.pad
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                z: BarLayout.left.indexOf(strip.dragId) >= 0 ? 1 : 0

                Repeater {
                    id: leftRep
                    model: BarLayout.left
                    delegate: barEntry
                }
            }

            Row {
                id: centreRow
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                z: BarLayout.centre.indexOf(strip.dragId) >= 0 ? 1 : 0

                Repeater {
                    id: centreRep
                    model: BarLayout.centre
                    delegate: barEntry
                }
            }

            Row {
                id: rightRow
                anchors.right: parent.right
                anchors.rightMargin: Theme.gap
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                z: BarLayout.right.indexOf(strip.dragId) >= 0 ? 1 : 0

                Repeater {
                    id: rightRep
                    model: BarLayout.right
                    delegate: barEntry
                }
            }

            // Where a release would put the item. The item under the pointer
            // says what is moving; this says where it lands, which the item
            // alone cannot -- it is halfway between two slots for most of the
            // gesture.
            Rectangle {
                visible: strip.dragId !== ""
                x: strip.dropX - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: Theme.barHeight - 12
                radius: 1
                color: Theme.accent
                z: 2
            }

            // --- one bar item -------------------------------------------------
            //
            // Everything in the bar is one of these. The wrapper carries the drag
            // gesture and a uniform bar-height grab area; the Loader carries
            // whatever the item actually is. One Component serves all three
            // zones: an entry does not know which zone it is in and does not need
            // to, because a drop names the zone it landed in.
            Component {
                id: barEntry

                Item {
                    id: entry

                    required property string modelData
                    readonly property string itemId: entry.modelData

                    // An item with nothing to show collapses rather than leaving
                    // a gap -- Bluetooth on a machine with no adapter, the tray
                    // with no icons. The item says so with `shown` rather than
                    // `visible`: `visible` read back through an invisible parent
                    // is already false, so binding to it would latch the entry
                    // off and never let it back.
                    readonly property bool shown: content.item ? content.item.shown !== false : false

                    visible: entry.shown
                    implicitWidth: content.implicitWidth
                    implicitHeight: Theme.barHeight

                    // The dragged item follows the pointer through a transform,
                    // not through x: the Row owns x and would overwrite it at the
                    // next relayout. A transform also leaves the item in the
                    // flow, so the gap it came from stays open while it moves.
                    z: drag.active ? 1 : 0
                    opacity: drag.active ? 0.7 : 1
                    transform: Translate {
                        x: drag.active ? drag.centroid.scenePosition.x - drag.centroid.scenePressPosition.x : 0
                    }

                    Loader {
                        id: content
                        anchors.centerIn: parent
                        sourceComponent: strip.componentFor(entry.itemId)
                    }

                    // A DragHandler, not a MouseArea. Every item already contains
                    // MouseAreas of its own -- click to open a popout, scroll to
                    // change the volume, click a tray icon -- and a pointer
                    // handler takes the grab from one of those only once the
                    // pointer has passed the drag threshold. So a click is still
                    // a click, and only a drag is a drag.
                    DragHandler {
                        id: drag
                        target: null
                        cursorShape: Qt.ClosedHandCursor

                        onActiveChanged: {
                            if (drag.active) {
                                strip.dragMove(entry.itemId, drag.centroid.scenePosition.x);
                                return;
                            }
                            // Committing rebuilds every delegate in the bar, this
                            // one included. Doing that from inside this handler's
                            // own signal destroys the handler mid-emit.
                            Qt.callLater(strip.dragEnd);
                        }

                        onCentroidChanged: {
                            if (drag.active)
                                strip.dragMove(entry.itemId, drag.centroid.scenePosition.x);
                        }
                    }
                }
            }

            // --- what the items are -------------------------------------------
            //
            // Unchanged from when they were anchored children, except that the
            // popout anchor is now measured through the scene: none of them can
            // assume which zone it is in any more.
            Component {
                id: workspacesItem
                Workspaces {}
            }

            Component {
                id: clockItem

                Indicator {
                    id: clockInd
                    name: "calendar"
                    active: Popouts.active === "calendar" && Popouts.anchorScreen === root.modelData
                    onActivated: Popouts.toggle("calendar", strip.fromRight(clockInd), root.modelData)

                    content: Clock {}
                }
            }

            // Other applications' tray icons. One entry, not one per icon: the
            // tray is kept visually separate from our indicators on purpose, and
            // an arrangement that could interleave a Steam icon with the volume
            // would lose that distinction the first time someone dragged
            // something. So the tray moves as a block and its contents stay
            // together and in the tray's own order.
            Component {
                id: trayItem
                SysTray {}
            }

            Component {
                id: netItem

                Indicator {
                    id: netInd
                    name: "net"
                    active: Popouts.active === "net" && Popouts.anchorScreen === root.modelData
                    onActivated: Popouts.toggle("net", strip.fromRight(netInd), root.modelData)

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

                        // A badge rather than a separate indicator: a generic
                        // tunnel is a property of the connection, not a peer of
                        // it. A WireGuard link really does ride on whichever link
                        // is underneath, and it has no state of its own worth
                        // watching -- it is up or it is down, which is exactly what
                        // a badge says.
                        //
                        // Tailscale is the deliberate exception and has its own
                        // indicator, to the right of this one. It is not a tunnel
                        // on this link: it is a network in its own right, with
                        // peers, exit nodes, its own DNS, file transfer, service
                        // publishing, and a notion of being up that does not care
                        // which link carries it. None of that fits in a badge, and
                        // "up through an exit node" is a state a badge cannot say
                        // at all. Net.qml drops tailscale0 from `tunnels` so the
                        // two never report the same thing twice.
                        //
                        // This is not a licence to promote the next VPN. The test
                        // is whether the thing has state of its own to show. If the
                        // answer is "it is up or it is down", it belongs here.
                        Badge {
                            visible: Net.tunnels.length > 0
                            iconName: "vpn"
                            color: Theme.mauve
                        }
                    }
                }
            }

            Component {
                id: tsItem

                Indicator {
                    id: tsInd
                    name: "ts"
                    active: Popouts.active === "ts" && Popouts.anchorScreen === root.modelData
                    onActivated: Popouts.toggle("ts", strip.fromRight(tsInd), root.modelData)
                    // Middle click skips the popout and opens the window. Every
                    // indicator already accepts a middle click and the ones with a
                    // single obvious action use it; here that action is "show me
                    // all of it", which is one click fewer than going via the menu.
                    onMiddleClicked: Ts.showWindow()

                    content: Row {
                        spacing: 6
                        Icon {
                            name: "tailscale"
                            size: Theme.iconSize
                            slash: !Ts.online
                            color: Ts.online ? (Ts.viaExitNode ? Theme.mauve : Theme.text) : Theme.overlay0
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        // The exit node's name, not a second icon. "Up" and "up
                        // through Amsterdam" are different enough facts that a
                        // badge could not tell them apart, and this is the state
                        // people forget they left switched on.
                        Text {
                            visible: Ts.viaExitNode
                            text: Ts.viaExitNode ? Ts.exitNode.host : ""
                            color: Theme.mauve
                            font.family: Theme.monoFamily
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            Component {
                id: btItem

                Indicator {
                    id: btInd
                    // `shown`, not `visible`: the entry that holds this has to be
                    // able to read the answer back to collapse its own slot.
                    readonly property bool shown: Bt.available

                    name: "bt"
                    active: Popouts.active === "bt" && Popouts.anchorScreen === root.modelData
                    onActivated: Popouts.toggle("bt", strip.fromRight(btInd), root.modelData)

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
            }

            Component {
                id: audioItem

                Indicator {
                    id: audioInd
                    name: "audio"
                    active: Popouts.active === "audio" && Popouts.anchorScreen === root.modelData
                    onActivated: Popouts.toggle("audio", strip.fromRight(audioInd), root.modelData)
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
            }

            Component {
                id: displayItem

                Indicator {
                    id: dispInd
                    name: "display"
                    active: Popouts.active === "display" && Popouts.anchorScreen === root.modelData
                    onActivated: Popouts.toggle("display", strip.fromRight(dispInd), root.modelData)

                    content: Icon {
                        name: "display"
                        size: Theme.iconSize
                        color: Theme.text
                    }
                }
            }

            Component {
                id: notifsItem

                Indicator {
                    id: notifInd
                    name: "notifs"
                    active: Popouts.active === "notifs" && Popouts.anchorScreen === root.modelData
                    onActivated: Popouts.toggle("notifs", strip.fromRight(notifInd), root.modelData)
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
            }

            Component {
                id: aiItem

                Indicator {
                    id: aiInd
                    name: "ai"
                    // `shown`, not `visible`: the entry that holds this has to be
                    // able to read the answer back to collapse its own slot.
                    // Hidden when no provider is configured, rather than showing a
                    // permanent question mark on an account that never signs in.
                    readonly property bool shown: AiUsage.available
                    active: Popouts.active === "ai" && Popouts.anchorScreen === root.modelData
                    onActivated: Popouts.toggle("ai", strip.fromRight(aiInd), root.modelData)

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
            }

            Component {
                id: sysItem

                Indicator {
                    id: sysInd
                    name: "sys"
                    active: Popouts.active === "sys" && Popouts.anchorScreen === root.modelData
                    onActivated: Popouts.toggle("sys", strip.fromRight(sysInd), root.modelData)

                    content: Row {
                        spacing: 6
                        Icon {
                            name: "cpu"
                            size: Theme.iconSize
                            // Amber and red at the same thresholds the gauges
                            // use, so the bar and the panel never disagree about
                            // whether something is worth looking at.
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
            }

            Component {
                id: powerItem

                Indicator {
                    id: powerInd
                    name: "power"
                    active: Popouts.active === "power" && Popouts.anchorScreen === root.modelData
                    onActivated: Popouts.toggle("power", strip.fromRight(powerInd), root.modelData)

                    content: Icon {
                        name: "power"
                        size: Theme.iconSize
                        color: Theme.text
                    }
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
                    sourceComponent: Popouts.active === "net" ? netPanel : Popouts.active === "bt" ? btPanel : Popouts.active === "audio" ? audioPanel : Popouts.active === "display" ? displayPanel : Popouts.active === "sys" ? sysPanel : Popouts.active === "notifs" ? notifPanel : Popouts.active === "calendar" ? calendarPanel : Popouts.active === "power" ? powerPanel : null
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
