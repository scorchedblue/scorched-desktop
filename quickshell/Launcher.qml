// The application launcher.
//
// Opened with SUPER+Space, which reaches this through `quickshell ipc call`
// rather than a compositor rule -- the window has to be created by the shell
// that owns it, and the keybind lives in Hyprland's config.
//
// Keyboard focus is Exclusive while open. That is deliberate and it is the
// whole point: a launcher that does not take the keyboard cannot be typed into.
// It is also why `visible` is bound tightly and why Escape is handled here --
// nothing else can receive keys while this is up.

import Quickshell
import Quickshell.Wayland
import QtQuick

Scope {
    id: root

    // Deliberately not per-screen. One launcher, on the primary output: a
    // launcher duplicated onto every monitor would take keyboard focus on all
    // of them and there is only one keyboard.
    property bool open: false

    property string query: ""
    property int selected: 0
    readonly property var results: Apps.search(query)

    function show() {
        // Rescan on open: something may have been installed since startup, and
        // this is the only moment where the cost is invisible.
        Apps.refresh();
        root.query = "";
        root.selected = 0;
        root.open = true;
    }

    function hide() {
        root.open = false;
    }

    function toggle() {
        if (root.open)
            hide();
        else
            show();
    }

    function activate() {
        const list = root.results;
        if (list.length === 0)
            return;
        Apps.launch(list[Math.max(0, Math.min(list.length - 1, root.selected))]);
        hide();
    }

    function move(delta) {
        const n = root.results.length;
        if (n === 0)
            return;
        // Wraps, so holding Down does not dead-end at the bottom.
        root.selected = (root.selected + delta + n) % n;
    }

    PanelWindow {
        id: win
        visible: root.open

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusiveZone: 0
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Dim the desktop behind. Not decoration: it is what makes a launcher
        // over a busy screen readable at all.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }
        }

        Rectangle {
            id: box

            // A third of the way down rather than centred: the eye rests above
            // the middle, and results grow downward from here.
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height / 4)

            width: 560
            height: header.height + list.height + (list.height > 0 ? Theme.pad : 0)
            radius: Theme.radius + 4
            color: Theme.mantle
            border.width: 1
            border.color: Theme.surface1

            Behavior on height {
                NumberAnimation {
                    duration: Theme.anim
                    easing.type: Easing.OutCubic
                }
            }

            // Swallow clicks so they do not reach the dimmer behind.
            MouseArea {
                anchors.fill: parent
            }

            // --- query line --------------------------------------------------
            Item {
                id: header
                width: parent.width
                height: 56

                Icon {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.pad + 4
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 18
                    color: Theme.overlay0
                }

                TextInput {
                    id: input
                    anchors.left: searchIcon.right
                    anchors.leftMargin: Theme.pad
                    anchors.right: countLabel.left
                    anchors.verticalCenter: parent.verticalCenter

                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.base
                    clip: true

                    // The single source of truth is root.query; this stays in
                    // step with it so clearing on open actually clears.
                    text: root.query
                    onTextChanged: {
                        if (text !== root.query) {
                            root.query = text;
                            root.selected = 0;
                        }
                    }

                    focus: root.open

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: input.text === ""
                        text: "Search applications"
                        color: Theme.overlay0
                        font: input.font
                    }

                    Keys.onEscapePressed: root.hide()
                    Keys.onReturnPressed: root.activate()
                    Keys.onEnterPressed: root.activate()
                    Keys.onDownPressed: root.move(1)
                    Keys.onUpPressed: root.move(-1)
                    // Ctrl+N / Ctrl+P as well, because anyone who reaches for a
                    // keyboard launcher probably has the habit.
                    Keys.onPressed: event => {
                        if (event.modifiers & Qt.ControlModifier) {
                            if (event.key === Qt.Key_N) {
                                root.move(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_P) {
                                root.move(-1);
                                event.accepted = true;
                            }
                        } else if (event.key === Qt.Key_Tab) {
                            root.move(1);
                            event.accepted = true;
                        }
                    }
                }

                Text {
                    id: countLabel
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.pad + 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.results.length + (Apps.all.length ? " / " + Apps.all.length : "")
                    color: Theme.overlay0
                    font.family: Theme.monoFamily
                    font.pixelSize: 11
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.surface0
                    visible: root.results.length > 0
                }
            }

            // --- results ------------------------------------------------------
            Column {
                id: list
                anchors.top: header.bottom
                anchors.topMargin: root.results.length > 0 ? Theme.gap : 0
                width: parent.width

                Repeater {
                    model: root.results

                    Rectangle {
                        required property var modelData
                        required property int index

                        width: list.width
                        height: 46
                        color: index === root.selected ? Theme.surface1 : rowMouse.containsMouse ? Theme.surface0 : "transparent"

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.pad + 4
                            anchors.right: shortcut.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                visible: modelData.comment !== ""
                                text: modelData.comment
                                color: Theme.overlay0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        Text {
                            id: shortcut
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.pad + 4
                            anchors.verticalCenter: parent.verticalCenter
                            visible: index === root.selected
                            text: "enter"
                            color: Theme.overlay0
                            font.family: Theme.monoFamily
                            font.pixelSize: 10
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selected = index
                            onClicked: {
                                root.selected = index;
                                root.activate();
                            }
                        }
                    }
                }
            }
        }
    }
}
