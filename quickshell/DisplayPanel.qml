// Display popout: what each monitor is doing, and a blank toggle.
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
    spacing: 4

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
                    width: 44
                    height: 24
                    radius: Theme.radius
                    color: autoMouse.containsMouse ? Theme.surface1 : Theme.surface0

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
                        // Aliased, because `modelData` means the rate here and
                        // the monitor one scope out. Naming it stops that being
                        // a puzzle every time this is read.
                        readonly property int rate: modelData
                        readonly property bool current: rate === mon.modelData.refresh

                        width: 54
                        height: 24
                        radius: Theme.radius
                        color: current ? Theme.accent : rateMouse.containsMouse ? Theme.surface1 : Theme.surface0

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
}
