// Session and power actions.
//
// Ordered by consequence, least first, and the two destructive ones are
// separated and coloured so that "log out" and "shut down" are never adjacent
// look-alikes. There is no confirmation step: these are one click from a menu
// the user opened on purpose, and a modal for every power action gets muscle-
// memoried away within a day.

import Quickshell
import Quickshell.Io
import QtQuick

Column {
    id: root
    spacing: 2

    Process {
        id: act
        command: ["true"]
    }

    function run(cmd) {
        act.command = cmd;
        act.running = true;
    }

    // Keyboard cursor into this panel's actions, driven by Bar.qml. Flat
    // index: the blank-when-idle switch, then its minute chips if it is on,
    // then the lock-when-idle switch, then the power actions -- the same
    // order they appear on screen.
    property int focusIndex: -1
    readonly property var blankMinuteOptions: [1, 5, 10, 15, 30, 60]
    readonly property int minuteCount: Idle.blankEnabled ? blankMinuteOptions.length : 0
    readonly property int lockSwitchIndex: 1 + minuteCount
    readonly property int actionsBase: lockSwitchIndex + 1
    readonly property int actionCount: actionsBase + powerActions.length

    readonly property var powerActions: [
        {
            label: "Blank screen",
            hint: "monitors off",
            danger: false,
            // Via screen-power.sh, never `hyprctl dispatch dpms` -- see that
            // script. Any input wakes the display again.
            cmd: ["bash", Quickshell.env("HOME") + "/.config/quickshell/screen-power.sh", "off"]
        },
        {
            label: "Lock",
            hint: "swaylock",
            danger: false,
            // Matches the SUPER+L binding, so the two never drift apart.
            cmd: ["swaylock", "-f"]
        },
        {
            label: "Log out",
            hint: "end session",
            danger: false,
            // Hyprland 0.56 takes Lua here. The old string dispatchers are
            // gone: `hyprctl dispatch exit` is a parse error, not a no-op.
            cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"]
        },
        {
            label: "Suspend",
            hint: "sleep",
            danger: false,
            cmd: ["systemctl", "suspend"]
        },
        {
            label: "Restart",
            hint: "reboot",
            danger: true,
            cmd: ["systemctl", "reboot"]
        },
        {
            label: "Shut down",
            hint: "power off",
            danger: true,
            cmd: ["systemctl", "poweroff"]
        }
    ]

    function activate(index) {
        if (index === 0) {
            Idle.setBlankEnabled(!Idle.blankEnabled);
            return;
        }
        if (minuteCount > 0 && index >= 1 && index < 1 + minuteCount) {
            Idle.setBlankMinutes(blankMinuteOptions[index - 1]);
            return;
        }
        if (index === lockSwitchIndex) {
            Idle.setLockEnabled(!Idle.lockEnabled);
            return;
        }
        const action = powerActions[index - actionsBase];
        if (action)
            root.run(action.cmd);
    }

    PanelHeader {
        title: "Session"
        subtitle: Quickshell.env("USER") + " on " + Quickshell.env("XDG_SESSION_TYPE")

        trailing: Icon {
            name: "power"
            size: 20
            color: Theme.accent
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    Item {
        width: parent.width
        height: 6
    }

    // --- screen -----------------------------------------------------------
    Text {
        text: "SCREEN"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.letterSpacing: 1
        font.weight: Font.DemiBold
    }

    ToggleRow {
        width: parent.width
        label: "Blank when idle"
        detail: Idle.blankMinutes + " min"
        checked: Idle.blankEnabled
        focused: root.focusIndex === 0
        onToggled: v => Idle.setBlankEnabled(v)
    }

    Flow {
        width: parent.width
        spacing: 4
        visible: Idle.blankEnabled

        Repeater {
            model: root.blankMinuteOptions

            Rectangle {
                required property int modelData
                required property int index
                readonly property bool current: modelData === Idle.blankMinutes
                readonly property bool focused: root.focusIndex === 1 + index

                width: 40
                height: 22
                radius: Theme.radius
                color: current ? Theme.accent : focused || minMouse.containsMouse ? Theme.surface1 : Theme.surface0
                border.width: focused && !current ? 2 : 0
                border.color: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData + "m"
                    color: parent.current ? Theme.base : Theme.subtext
                    font.family: Theme.monoFamily
                    font.pixelSize: 10
                }
                MouseArea {
                    id: minMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Idle.setBlankMinutes(parent.modelData)
                }
            }
        }
    }

    ToggleRow {
        width: parent.width
        label: "Lock when idle"
        detail: Idle.lockMinutes + " min"
        checked: Idle.lockEnabled
        focused: root.focusIndex === root.lockSwitchIndex
        onToggled: v => Idle.setLockEnabled(v)
    }

    Item {
        width: parent.width
        height: 6
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    Item {
        width: parent.width
        height: 6
    }

    Repeater {
        model: root.powerActions

        Rectangle {
            required property var modelData
            required property int index
            readonly property bool focused: root.focusIndex === root.actionsBase + index

            width: parent.width
            height: 32
            radius: Theme.radius
            color: focused || powMouse.containsMouse ? (modelData.danger ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.18) : Theme.surface0) : "transparent"
            border.width: focused ? 2 : 0
            border.color: Theme.accent

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                color: modelData.danger && (focused || powMouse.containsMouse) ? Theme.red : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.hint
                color: Theme.overlay0
                font.family: Theme.monoFamily
                font.pixelSize: 10
            }

            MouseArea {
                id: powMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.run(modelData.cmd)
            }
        }
    }
}
