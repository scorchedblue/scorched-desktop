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

    // Keyboard cursor into this panel's actions, driven by Bar.qml. Flat
    // index across both sections: output volume, then each output device,
    // then (if there is one) input volume, then each input device.
    property int focusIndex: -1
    readonly property int sinkCount: Audio.sinks.length
    readonly property int sourceCount: Audio.sources.length
    readonly property bool hasInput: sourceCount > 0
    readonly property int inputMuteIndex: sinkCount + 1
    readonly property int actionCount: 1 + sinkCount + (hasInput ? 1 + sourceCount : 0)

    function activate(index) {
        if (index === 0) {
            Audio.toggleMute();
            return;
        }
        if (index <= sinkCount) {
            const sink = Audio.sinks[index - 1];
            if (sink)
                Audio.setSink(sink.name);
            return;
        }
        if (!hasInput)
            return;
        if (index === inputMuteIndex) {
            Audio.toggleInputMute();
            return;
        }
        const source = Audio.sources[index - inputMuteIndex - 1];
        if (source)
            Audio.setSource(source.name);
    }

    // Left/Right only make sense on the two volume rows -- device rows have
    // nothing to adjust.
    function adjust(index, delta) {
        if (index === 0) {
            Audio.setVolume(Audio.volume + delta);
            return;
        }
        if (hasInput && index === inputMuteIndex)
            Audio.setInputVolume(Audio.inputVolume + delta);
    }

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
        focused: root.focusIndex === 0
        onMuteRequested: Audio.toggleMute()
        onValueRequested: v => Audio.setVolume(v)
    }

    Repeater {
        model: Audio.sinks

        DeviceRow {
            required property var modelData
            required property int index
            width: parent.width
            label: modelData.description
            selected: modelData.active
            focused: root.focusIndex === index + 1
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
        focused: root.focusIndex === root.inputMuteIndex
        onMuteRequested: Audio.toggleInputMute()
        onValueRequested: v => Audio.setInputVolume(v)
    }

    Repeater {
        model: Audio.sources

        DeviceRow {
            required property var modelData
            required property int index
            width: parent.width
            label: modelData.description
            selected: modelData.active
            focused: root.focusIndex === root.inputMuteIndex + 1 + index
            onPicked: Audio.setSource(modelData.name)
        }
    }
}
