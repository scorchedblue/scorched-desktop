// Bar clock.
//
// Minutes precision deliberately: a seconds-precision clock wakes the process
// every second for a display that does not show seconds.

import Quickshell
import QtQuick

Text {
    // In Qt's format strings `h` only means 12-hour when an AP/ap specifier is
    // present. Without it, `h` is 24-hour and the clock is silently wrong for
    // half of every day.
    text: Qt.formatDateTime(clock.date, "ddd d MMM   h:mm AP")
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
