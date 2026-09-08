// Display popout: what each monitor is doing, and the bar's arrangement.
//
// The bar's reset lives here because this is the panel about what is on the
// screen, and the bar is on the screen. It has to live *somewhere* reachable:
// bar items are dragged, and a rearrangement a user cannot undo without opening
// a text editor is a trap.
//
// Reports rather than controls, and both omissions are deliberate.
//
// No brightness slider: there is no backlight device on this class of machine,
// and an external monitor needs DDC/CI through ddcutil, which the image does not
// ship.
//
// No blank-screen toggle: Hyprland 0.56's dpms dispatcher ignores its argument
// and toggles, so a switch here could not be trusted to reach the state it
// claims. A control that moves and does nothing is bad; one that can leave the
// screen dark is worse.

import QtQuick

Column {
    id: root
    spacing: 4

    // Keyboard cursor into this panel's actions, driven by Bar.qml. Flat
    // across every monitor that has more than one rate on offer: "Auto",
    // then each rate, for the first such monitor, then the same for the
    // next, and the bar's reset last. A monitor with only one rate
    // contributes nothing to navigate -- its chips are not shown either, see
    // the Flow below.
    property int focusIndex: -1

    function monitorActionCount(mon) {
        return mon.rates.length > 1 ? 1 + mon.rates.length : 0;
    }

    readonly property int rateActionCount: {
        let n = 0;
        for (const mon of Displays.monitors)
            n += monitorActionCount(mon);
        return n;
    }

    readonly property int resetIndex: rateActionCount
    readonly property int actionCount: rateActionCount + 1

    // rateIndex -1 means the "Auto" chip; 0..n-1 means that entry in
    // mon.rates.
    function flatIndex(monIndex, rateIndex) {
        let base = 0;
        for (let m = 0; m < monIndex; m++)
            base += monitorActionCount(Displays.monitors[m]);
        return base + rateIndex + 1;
    }

    function activate(index) {
        if (index === root.resetIndex) {
            BarLayout.reset();
            return;
        }
        let base = 0;
        for (let m = 0; m < Displays.monitors.length; m++) {
            const mon = Displays.monitors[m];
            const n = monitorActionCount(mon);
            if (index < base + n) {
                const local = index - base;
                if (local === 0)
                    Displays.setAutoMode(mon.name);
                else
                    Displays.setMode(mon.name, mon.width, mon.height, mon.rates[local - 1]);
                return;
            }
            base += n;
        }
    }

    PanelHeader {
        title: "Displays"
        subtitle: Displays.monitors.length === 1 ? "1 monitor" : Displays.monitors.length + " monitors"

        trailing: Icon {
            name: "display"
            size: 20
            color: Theme.accent
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    Repeater {
        model: Displays.monitors

        Column {
            id: mon
            required property var modelData
            required property int index
            width: parent.width
            spacing: 2

            Item {
                width: parent.width
                height: 8
            }

            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: modelData.name
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    visible: modelData.focused
                    width: 40
                    height: 15
                    radius: 4
                    color: Theme.surface1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "focus"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                    }
                }
            }

            Text {
                text: modelData.description
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
                width: parent.width
            }

            StatRow {
                label: "Mode"
                value: modelData.width + "x" + modelData.height + " @ " + modelData.refresh + "Hz"
            }
            StatRow {
                label: "Scale"
                value: modelData.scale + "x"
            }

            StatRow {
                label: "Position"
                value: modelData.x + ", " + modelData.y
            }
            StatRow {
                label: "Workspace"
                value: modelData.workspace || "-"
            }

            // Refresh rate picker. Only rates at the monitor's current
            // resolution are offered -- see Displays.qml. Everything here is
            // one click, because Hyprland applies a mode immediately and
            // reverts nothing, so a confirm step would be theatre.
            Item {
                width: parent.width
                height: 6
                visible: mon.modelData.rates.length > 1
            }

            Text {
                visible: mon.modelData.rates.length > 1
                text: "REFRESH RATE"
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 1
                font.weight: Font.DemiBold
            }

            Flow {
                width: parent.width
                spacing: 4
                visible: mon.modelData.rates.length > 1

                Rectangle {
                    id: autoChip
                    readonly property bool focused: root.focusIndex === root.flatIndex(mon.index, -1)

                    width: 44
                    height: 24
                    radius: Theme.radius
                    color: focused || autoMouse.containsMouse ? Theme.surface1 : Theme.surface0
                    border.width: focused ? 2 : 0
                    border.color: Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: "Auto"
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: autoMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Displays.setAutoMode(mon.modelData.name)
                    }
                }

                Repeater {
                    model: mon.modelData.rates

                    Rectangle {
                        id: chip
                        required property int modelData
                        required property int index
                        // Aliased, because `modelData` means the rate here and
                        // the monitor one scope out. Naming it stops that being
                        // a puzzle every time this is read.
                        readonly property int rate: modelData
                        readonly property bool current: rate === mon.modelData.refresh
                        readonly property bool focused: root.focusIndex === root.flatIndex(mon.index, index)

                        width: 54
                        height: 24
                        radius: Theme.radius
                        color: current ? Theme.accent : focused || rateMouse.containsMouse ? Theme.surface1 : Theme.surface0
                        border.width: focused && !current ? 2 : 0
                        border.color: Theme.accent

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.anim
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: chip.rate + " Hz"
                            color: chip.current ? Theme.base : Theme.text
                            font.family: Theme.monoFamily
                            font.pixelSize: 10
                            font.weight: chip.current ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: rateMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Displays.setMode(mon.modelData.name, mon.modelData.width, mon.modelData.height, chip.rate)
                        }
                    }
                }
            }

        }
    }

    // --- the bar ------------------------------------------------------------
    Item {
        width: parent.width
        height: 10
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    Item {
        width: parent.width
        height: 8
    }

    Text {
        text: "BAR"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.letterSpacing: 1
        font.weight: Font.DemiBold
    }

    Item {
        width: parent.width
        height: 4
    }

    Row {
        width: parent.width
        spacing: 8

        Rectangle {
            id: resetChip
            readonly property bool focused: root.focusIndex === root.resetIndex

            width: 96
            height: 24
            radius: Theme.radius
            color: focused || resetMouse.containsMouse ? Theme.surface1 : Theme.surface0
            border.width: focused ? 2 : 0
            border.color: Theme.accent

            Behavior on color {
                ColorAnimation {
                    duration: Theme.anim
                }
            }

            Text {
                anchors.centerIn: parent
                text: "Reset layout"
                // Dimmed rather than hidden or disabled when there is nothing
                // to reset: a control that vanishes is one the user has to
                // rediscover, and this is the only place the arrangement can be
                // undone from.
                color: BarLayout.customised ? Theme.text : Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            MouseArea {
                id: resetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: BarLayout.reset()
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: BarLayout.customised ? "rearranged" : "as shipped"
            color: Theme.overlay0
            font.family: Theme.monoFamily
            font.pixelSize: 10
        }
    }
}
