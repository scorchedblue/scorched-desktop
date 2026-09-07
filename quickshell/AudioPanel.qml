// Audio popout: output and input, each with a level meter and a device picker.
//
// Device switching is the reason this panel exists. This machine has four sinks
// and three real sources, and choosing between them otherwise means opening a
// settings app.

import QtQuick

Column {
    id: root
    spacing: 4

    // Meters cost nothing while running but there is no reason to run them at
    // all when the panel is closed, so they follow this panel's lifetime.
    Component.onCompleted: Audio.metering = true
    Component.onDestruction: Audio.metering = false

    PanelHeader {
        title: "Audio"
        subtitle: Audio.sinkDescription || "No output"

        trailing: Text {
            text: Audio.muted ? "Muted" : Audio.volume + "%"
            color: Audio.muted ? Theme.red : Theme.text
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSize
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    // ======================= OUTPUT =======================
    Item {
        width: parent.width
        height: 8
    }

    Text {
        text: "OUTPUT"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.letterSpacing: 1
        font.weight: Font.DemiBold
    }

    VolumeRow {
        width: parent.width
        icon: "volume"
        level: Audio.level
        muted: Audio.muted
        value: Audio.volume
        meter: Audio.outputLevel
        onMuteRequested: Audio.toggleMute()
        onValueRequested: v => Audio.setVolume(v)
    }

    Repeater {
        model: Audio.sinks

        DeviceRow {
            required property var modelData
            width: parent.width
            label: modelData.description
            selected: modelData.active
            onPicked: Audio.setSink(modelData.name)
        }
    }

    // ======================= INPUT ========================
    Item {
        width: parent.width
        height: 12
        visible: Audio.sources.length > 0
    }

    Text {
        visible: Audio.sources.length > 0
        text: "INPUT"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.letterSpacing: 1
        font.weight: Font.DemiBold
    }

    Text {
        visible: Audio.sources.length === 0
        text: "No input device"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    VolumeRow {
        visible: Audio.sources.length > 0
        width: parent.width
        icon: "mic"
        level: Audio.inLevel
        muted: Audio.inputMuted
        value: Audio.inputVolume
        meter: Audio.inputLevel
        meterColour: Theme.teal
        onMuteRequested: Audio.toggleInputMute()
        onValueRequested: v => Audio.setInputVolume(v)
    }

    Repeater {
        model: Audio.sources

        DeviceRow {
            required property var modelData
            width: parent.width
            label: modelData.description
            selected: modelData.active
            onPicked: Audio.setSource(modelData.name)
        }
    }
}
