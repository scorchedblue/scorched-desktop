// One notification toast.
//
// Owns its own lifetime: the countdown lives here rather than in a central
// sweeper, so hovering pauses only this toast and the timer disappears with the
// delegate when it goes.

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Rectangle {
    id: root

    required property var notif

    readonly property bool critical: notif.urgency === NotificationUrgency.Critical
    readonly property int timeout: Notifs.timeoutFor(notif)

    width: Theme.popoutWidth
    implicitHeight: body.implicitHeight + Theme.pad * 2
    radius: Theme.radius + 2
    color: Theme.mantle
    border.width: 1
    // Critical toasts are outlined in red rather than merely coloured inside,
    // so urgency is visible from the corner of the eye.
    border.color: root.critical ? Theme.red : Theme.surface1

    // Slide in from the right rather than appearing. A toast that materialises
    // mid-screen is easy to miss entirely.
    x: Theme.gap
    opacity: 0
    Component.onCompleted: opacity = 1

    Behavior on opacity {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    // Auto-dismiss, unless critical (timeout 0) or the pointer is on it.
    // Hovering pauses: reading a toast should not race a countdown.
    Timer {
        running: root.timeout > 0 && !hover.containsMouse
        interval: root.timeout
        onTriggered: Notifs.removePopup(root.notif)
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            // Left click dismisses the toast but keeps the notification in
            // history; middle click discards it entirely.
            if (mouse.button === Qt.MiddleButton)
                Notifs.dismiss(root.notif);
            else
                Notifs.removePopup(root.notif);
        }
    }

    Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.pad
        spacing: 4

        Row {
            width: parent.width
            spacing: 8

            // The sender's icon, when it gave one. `image` is already a QML
            // image-provider URL, so it needs no translation.
            Image {
                width: 22
                height: 22
                source: root.notif.image || root.notif.appIcon || ""
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                width: parent.width - 30 - closeHint.width
                text: root.notif.summary
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                id: closeHint
                text: root.notif.appName
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.notif.body
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
            // bodyMarkupSupported is declared, so the body may contain the
            // small subset of markup the spec allows.
            textFormat: Text.StyledText
        }

        Row {
            visible: root.notif.actions && root.notif.actions.length > 0
            spacing: 6
            topPadding: 4

            Repeater {
                model: root.notif.actions

                Rectangle {
                    required property var modelData

                    width: actionLabel.implicitWidth + 18
                    height: 24
                    radius: Theme.radius
                    color: actMouse.containsMouse ? Theme.surface1 : Theme.surface0

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: modelData.text
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    MouseArea {
                        id: actMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            modelData.invoke();
                            Notifs.removePopup(root.notif);
                        }
                    }
                }
            }
        }
    }
}
