pragma Singleton

// One place for every colour, size and duration in the shell.
//
// Nothing else in this configuration hardcodes a colour. When the palette is
// wrong, it is wrong here and only here.

import Quickshell
import QtQuick

Singleton {
    // --- palette ---------------------------------------------------------
    // Catppuccin Mocha. Chosen because the bar already used it and the greeter
    // can be matched to it exactly, so the session looks like one product from
    // the login prompt onward.
    readonly property color base: "#1e1e2e"
    readonly property color mantle: "#181825"
    readonly property color crust: "#11111b"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color overlay0: "#6c7086"
    readonly property color subtext: "#a6adc8"
    readonly property color text: "#cdd6f4"

    readonly property color accent: "#89b4fa"
    readonly property color green: "#a6e3a1"
    readonly property color yellow: "#f9e2af"
    readonly property color red: "#f38ba8"
    readonly property color mauve: "#cba6f7"
    readonly property color teal: "#94e2d5"

    // --- geometry --------------------------------------------------------
    readonly property int barHeight: 34
    readonly property int gap: 8
    readonly property int pad: 10
    readonly property int radius: 8
    readonly property int iconSize: 16

    readonly property int popoutWidth: 340
    readonly property int popoutMaxHeight: 560

    // --- type ------------------------------------------------------------
    // No Nerd Font is assumed: the image ships none, and depending on one that
    // only exists in a user's home would break the shell for a fresh account.
    // Every icon in this shell is drawn, not typed. See Icon.qml.
    readonly property string fontFamily: "Adwaita Sans"
    readonly property string monoFamily: "Adwaita Mono"
    readonly property int fontSize: 12
    readonly property int fontSizeSmall: 11

    // --- motion ----------------------------------------------------------
    // Short enough to feel immediate, long enough to read as deliberate.
    readonly property int anim: 120
}
