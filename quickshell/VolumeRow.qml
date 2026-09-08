// A mute button, a volume slider and a live meter, as one unit.
//
// Used for both output and input so the two behave identically -- the only
// difference between them should be which device they point at.

import QtQuick

Item {
    id: root

    property string icon: "volume"
    property int level: 2
    property bool muted: false
    property int value: 0
    property int meter: 0
    property color meterColour: Theme.green
    // Set from outside by whatever is driving keyboard navigation. Left/Right
    // adjust the value while this row is the keyboard cursor's stop; that
    // logic lives in the panel, not here, since only the panel knows the
    // flat index this row sits at.
    property bool focused: false

    // `set` and `toggle` are both special to the QML parser, hence the
    // longer names.
    signal muteRequested
    signal valueRequested(int value)

    implicitHeight: 40

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 10

        Rectangle {
            width: 26
            height: 26
            radius: Theme.radius
            color: muteMouse.containsMouse ? Theme.surface0 : "transparent"
            border.width: root.focused ? 2 : 0
            border.color: Theme.accent

            Icon {
                anchors.centerIn: parent
                name: root.icon
                size: 16
                level: root.level
                slash: root.muted
                color: root.muted ? Theme.red : Theme.text
            }
            MouseArea {
                id: muteMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.muteRequested()
            }
        }

        // Click or drag anywhere on the track. A grab handle would be a smaller
        // target for no benefit at this size.
        Item {
            id: track
            width: parent.width - 36 - 44
            height: 26

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Theme.surface1

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(100, root.value)) / 100
                    height: parent.height
                    radius: 3
                    color: root.muted ? Theme.overlay0 : Theme.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: 60
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => root.valueRequested(mouse.x / width * 100)
                onPositionChanged: mouse => {
                    if (pressed)
                        root.valueRequested(mouse.x / width * 100);
                }
            }
        }

        Text {
            width: 34
            text: root.muted ? "--" : root.value + "%"
            color: root.muted ? Theme.red : Theme.subtext
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // The meter sits under the slider it belongs to, indented to line up with
    // the track rather than the icon.
    LevelMeter {
        anchors.left: parent.left
        anchors.leftMargin: 36
        anchors.right: parent.right
        anchors.rightMargin: 44
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        value: root.muted ? 0 : root.meter
        fill: root.meterColour
    }
}
