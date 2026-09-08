// Month calendar, opened from the clock.
//
// Built from a plain Grid rather than QtQuick.Controls' MonthGrid, so it needs
// no Controls import, no style, and it inherits Theme like everything else. A
// month is six rows of seven cells and the arithmetic is four lines; pulling in
// a styled control to avoid writing them would cost more than it saved.

import Quickshell
import QtQuick

Column {
    id: root
    spacing: 4

    // The month being displayed. Starts on today and moves with the arrows.
    property date shown: new Date()
    readonly property date today: clock.date

    // Keyboard cursor into this panel's actions, driven by Bar.qml: the three
    // header buttons, in the order they appear. The day grid is not
    // clickable either, so there is nothing further to navigate to.
    property int focusIndex: -1
    readonly property int actionCount: 3

    function activate(index) {
        if (index === 0)
            root.step(-1);
        else if (index === 1)
            root.shown = new Date();
        else if (index === 2)
            root.step(1);
    }

    readonly property int shownYear: shown.getFullYear()
    readonly property int shownMonth: shown.getMonth()

    // Day-of-week for the 1st, and the length of the month. Day 0 of the next
    // month is the last day of this one, which is the shortest correct way to
    // ask how many days a month has.
    readonly property int firstWeekday: new Date(shownYear, shownMonth, 1).getDay()
    readonly property int daysInMonth: new Date(shownYear, shownMonth + 1, 0).getDate()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function step(months) {
        root.shown = new Date(root.shownYear, root.shownMonth + months, 1);
    }

    // --- header -----------------------------------------------------------
    Item {
        width: parent.width
        height: 32

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDate(root.shown, "MMMM yyyy")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.DemiBold
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            NavButton {
                rotation: 90
                focused: root.focusIndex === 0
                onTriggered: root.step(-1)
            }
            NavButton {
                label: "today"
                wide: true
                focused: root.focusIndex === 1
                onTriggered: root.shown = new Date()
            }
            NavButton {
                rotation: -90
                focused: root.focusIndex === 2
                onTriggered: root.step(1)
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    Item {
        width: parent.width
        height: 4
    }

    // --- weekday headings -------------------------------------------------
    Grid {
        width: parent.width
        columns: 7

        Repeater {
            model: ["S", "M", "T", "W", "T", "F", "S"]

            Item {
                required property string modelData
                required property int index
                width: root.width / 7
                height: 18

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    // Weekends dimmed, so the shape of the week is visible
                    // without reading any letters.
                    color: (index === 0 || index === 6) ? Theme.overlay0 : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    // --- the days ---------------------------------------------------------
    Grid {
        width: parent.width
        columns: 7

        Repeater {
            // 42 cells: six weeks, which is the most any month can span. Cells
            // before the 1st and after the last are blank rather than showing
            // neighbouring months, so the eye never mistakes one for today.
            model: 42

            Item {
                required property int index
                readonly property int day: index - root.firstWeekday + 1
                readonly property bool real: day >= 1 && day <= root.daysInMonth
                readonly property bool isToday: real && day === root.today.getDate() && root.shownMonth === root.today.getMonth() && root.shownYear === root.today.getFullYear()

                width: root.width / 7
                height: 26

                Rectangle {
                    anchors.centerIn: parent
                    width: 24
                    height: 22
                    radius: Theme.radius - 2
                    color: parent.isToday ? Theme.accent : "transparent"
                    visible: parent.real

                    Text {
                        anchors.centerIn: parent
                        text: parent.parent.day
                        color: parent.parent.isToday ? Theme.base : (parent.parent.index % 7 === 0 || parent.parent.index % 7 === 6) ? Theme.overlay0 : Theme.text
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: parent.parent.isToday ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }

    Item {
        width: parent.width
        height: 4
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    StatRow {
        label: "Today"
        value: Qt.formatDate(root.today, "dddd d MMMM yyyy")
    }
    StatRow {
        label: "Week"
        // ISO week number: Thursday of the current week decides the year, which
        // is the whole trick to getting the boundary weeks right.
        value: {
            const d = new Date(root.today.getFullYear(), root.today.getMonth(), root.today.getDate());
            d.setDate(d.getDate() + 4 - (d.getDay() || 7));
            const yearStart = new Date(d.getFullYear(), 0, 1);
            return "W" + Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
        }
    }
}
