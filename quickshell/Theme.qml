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

    // Spacing between one indicator and the next in the bar's tray, and
    // between an indicator's icon and any label beside it. One value each,
    // so every indicator reads as the same family rather than each widget
    // picking its own gap.
    readonly property int indicatorSpacing: 2
    readonly property int contentSpacing: 6

    // A badge -- the VPN mark, the notification count -- pinned to a corner
    // of the icon it belongs to. One offset, ring and size for both, so they
    // sit the same way on every icon that carries one.
    readonly property int badgeSize: 13
    readonly property int badgeIconSize: 9
    readonly property int badgeOffset: -5
    readonly property int badgeRing: 2
    readonly property int badgeFontSize: 8

    readonly property int popoutWidth: 340
    readonly property int popoutMaxHeight: 560

    // A window, as opposed to a popout: what an indicator opens when its
    // surface is too big for a menu. Wider because it carries lists several
    // columns across, and capped in height so it still fits a laptop panel.
    readonly property int windowWidth: 720
    readonly property int windowMaxHeight: 720

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
