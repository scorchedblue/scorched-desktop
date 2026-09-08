pragma Singleton

// Shared state for the bar popout: which one is open, which screen it
// belongs to, and where the keyboard cursor sits inside it.
//
// A popout can be opened two ways: a click on a bar indicator, which already
// knows its own screen and the indicator's pixel position, or a keybinding,
// which knows neither. Both have to agree on what is open, so that state
// lives here rather than inside any one screen's Bar.
//
// focusIndex is the keyboard cursor within whatever panel is loaded. -1 means
// nothing is focused yet -- the panel looks exactly as it does for a mouse
// user until a key actually moves it, so opening a popout with a keybinding
// does not draw a highlight nobody asked for.

import Quickshell
import QtQuick

Singleton {
    id: root

    property string active: ""
    property real anchorFromRight: 0
    property var anchorScreen: null
    property int focusIndex: -1

    onActiveChanged: root.focusIndex = -1

    function open(name, fromRight, onScreen) {
        root.active = name;
        root.anchorFromRight = fromRight;
        root.anchorScreen = onScreen;
    }

    function close() {
        root.active = "";
    }

    function toggle(name, fromRight, onScreen) {
        if (root.active === name && root.anchorScreen === onScreen)
            root.close();
        else
            root.open(name, fromRight, onScreen);
    }
}
