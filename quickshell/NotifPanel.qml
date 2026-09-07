// Notification history.
//
// The toasts are transient by design; this is where anything missed while
// looking elsewhere can still be found.

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Column {
    spacing: 4

    PanelHeader {
        title: "Notifications"
        subtitle: Notifs.count === 0 ? "Nothing waiting" : Notifs.count + (Notifs.count === 1 ? " notification" : " notifications")

        trailing: Rectangle {
            visible: Notifs.count > 0
            width: clearLabel.implicitWidth + 16
            height: 22
            radius: Theme.radius
            color: clearMouse.containsMouse ? Theme.surface1 : Theme.surface0

            Text {
                id: clearLabel
                anchors.centerIn: parent
                text: "Clear all"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.clearAll()
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    Text {
        visible: Notifs.count === 0
        text: "Nothing here yet"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        topPadding: Theme.pad
    }

    Repeater {
        model: Notifs.all

        Rectangle {
            required property var modelData

            width: parent.width
            implicitHeight: row.implicitHeight + 12
            radius: Theme.radius
            color: itemMouse.containsMouse ? Theme.surface0 : "transparent"

            Column {
                id: row
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 2

                Row {
                    width: parent.width
                    spacing: 6

                    Rectangle {
                        // A dot rather than a word: urgency is worth showing and
                        // not worth a label on every row.
                        width: 6
                        height: 6
                        radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData.urgency === NotificationUrgency.Critical ? Theme.red : modelData.urgency === NotificationUrgency.Low ? Theme.overlay0 : Theme.accent
                    }
                    Text {
                        text: modelData.summary
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        width: parent.width - 12 - appLabel.width - 12
                    }
                    Text {
                        id: appLabel
                        text: modelData.appName
                        color: Theme.overlay0
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: modelData.body
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                }
            }

            MouseArea {
                id: itemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.dismiss(modelData)
            }
        }
    }
}
