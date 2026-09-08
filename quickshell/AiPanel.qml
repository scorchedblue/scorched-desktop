// AI assistant usage popout: how much of each window is spent, when each one
// resets, and which model is in use.
//
// Everything here is driven off the provider's window list rather than off two
// named fields, so a provider that reports three windows -- or a second
// provider entirely -- needs no change here.
//
// A window whose percentage is unknown gets no bar at all. An empty track reads
// as 0%, and 0% is precisely the wrong thing to tell someone who is about to
// start a long task.

import QtQuick

Column {
    spacing: 4

    // The panel is only built when it is opened, which is a good moment to ask
    // for a fresh number rather than show one up to two minutes old.
    Component.onCompleted: AiUsage.refresh()

    PanelHeader {
        title: AiUsage.providerName !== "" ? AiUsage.providerName : "AI usage"
        subtitle: AiUsage.locked ? "Limit reached" : AiUsage.sessionPercent < 0 ? "Usage unavailable" : "Session and weekly limits"

        trailing: Icon {
            name: "sparkle"
            size: 20
            color: AiUsage.locked ? Theme.red : AiUsage.sessionPercent < 0 ? Theme.overlay0 : Theme.accent
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

    Repeater {
        model: AiUsage.primary ? AiUsage.primary.windows : []

        Item {
            id: row

            required property var modelData
            readonly property real pct: AiUsage.percentOf(row.modelData)

            width: parent.width
            implicitHeight: 34

            Gauge {
                visible: row.pct >= 0
                anchors.fill: parent
                iconName: "sparkle"
                label: row.modelData.label
                percent: Math.round(row.pct)
                detail: AiUsage.percentText(row.modelData)
            }

            StatRow {
                visible: row.pct < 0
                anchors.verticalCenter: parent.verticalCenter
                label: row.modelData.label
                value: "unknown"
                valueColor: Theme.overlay0
            }
        }
    }

    Item {
        width: parent.width
        height: 6
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

    // The field that says you are actually limited, rather than merely close to
    // it. Worth its own row, in red, above everything else.
    StatRow {
        visible: AiUsage.lockedReason !== ""
        label: "Limited"
        value: AiUsage.lockedReason
        valueColor: Theme.red
    }

    Repeater {
        model: AiUsage.primary ? AiUsage.primary.windows : []

        StatRow {
            required property var modelData
            label: modelData.label + " resets"
            value: AiUsage.resetText(modelData)
            valueColor: value === "unknown" ? Theme.overlay0 : Theme.text
        }
    }

    StatRow {
        label: "Model"
        value: AiUsage.model !== "" ? AiUsage.model : "unknown"
        valueColor: AiUsage.model !== "" ? Theme.text : Theme.overlay0
    }
}
