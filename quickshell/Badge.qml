// A marker pinned to the top-right corner of whatever icon it sits on.
//
// The VPN mark and the notification count are the same shape at the same
// offset, ringed in the bar's own colour so neither merges into the icon
// behind it. Set exactly one of `text` or `iconName`.

import QtQuick

Rectangle {
    id: root

    property string text: ""
    property string iconName: ""

    anchors.right: parent.right
    anchors.rightMargin: Theme.badgeOffset
    anchors.top: parent.top
    anchors.topMargin: Theme.badgeOffset

    implicitWidth: Math.max(Theme.badgeSize, label.implicitWidth + 6)
    implicitHeight: Theme.badgeSize
    radius: height / 2
    border.width: Theme.badgeRing
    border.color: Theme.base

    Text {
        id: label
        anchors.centerIn: parent
        visible: root.text.length > 0
        text: root.text
        color: Theme.base
        font.family: Theme.monoFamily
        font.pixelSize: Theme.badgeFontSize
        font.weight: Font.DemiBold
    }

    Icon {
        anchors.centerIn: parent
        visible: root.iconName.length > 0
        name: root.iconName
        size: Theme.badgeIconSize
        color: Theme.base
    }
}
