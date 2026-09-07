// A live peak meter.
//
// Rises instantly and falls slowly. A meter that tracks the signal exactly in
// both directions reads as noise -- the eye cannot follow a bar that drops to
// zero between syllables -- so the fall is damped while the rise is not, which
// is what every hardware meter does and why they are readable.

import QtQuick

Item {
    id: root

    property int value: 0        // 0-100, the live peak
    property bool active: true
    property color fill: Theme.green

    implicitHeight: 4

    // The displayed value, which only ever falls gradually.
    property real shown: 0

    onValueChanged: {
        if (value > shown)
            shown = value;   // attack: immediate
    }

    Timer {
        interval: 50
        running: root.active
        repeat: true
        // Decay: about 60 points a second, so a peak stays legible for roughly
        // a second and a half before the bar is empty again.
        onTriggered: root.shown = Math.max(root.value, root.shown - 3)
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surface1

        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, root.shown)) / 100
            height: parent.height
            radius: parent.radius
            // Green through to red as the signal approaches clipping, so
            // "too loud" is visible without reading a number.
            color: root.shown >= 90 ? Theme.red : root.shown >= 70 ? Theme.yellow : root.fill

            Behavior on width {
                NumberAnimation {
                    duration: 45
                }
            }
        }
    }
}
