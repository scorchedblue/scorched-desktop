pragma Singleton

// Audio state, via pactl, plus live peak metering.
//
// pactl speaks JSON (-f json), which is why it is used here rather than wpctl:
// parsing wpctl's tree output means matching on box-drawing characters, and
// that breaks the first time upstream prettifies it.
//
// Outputs and inputs are fetched in one shell invocation together with the two
// defaults. Separate Processes on separate timers would drift and briefly
// disagree, which shows up as a flickering volume number.
//
// Metering runs only while something is watching (see `metering`). Two parec
// pipelines left running forever would be rude even at 0% CPU.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // --- output ----------------------------------------------------------
    property int volume: 0
    property bool muted: false
    property string sinkName: ""
    property string sinkDescription: ""
    property var sinks: []

    // --- input -----------------------------------------------------------
    property int inputVolume: 0
    property bool inputMuted: false
    property string sourceName: ""
    property string sourceDescription: ""
    property var sources: []

    // --- live levels, 0-100 ----------------------------------------------
    property int outputLevel: 0
    property int inputLevel: 0

    // Meters are expensive to leave running and pointless when nothing is
    // looking at them. The audio panel sets this while it is open.
    property bool metering: false

    readonly property int level: muted ? 0 : volume >= 55 ? 2 : volume >= 1 ? 1 : 0
    readonly property int inLevel: inputMuted ? 0 : inputVolume >= 55 ? 2 : inputVolume >= 1 ? 1 : 0

    function refresh() {
        query.running = true;
    }

    // --- output actions ---------------------------------------------------
    function setVolume(pct) {
        const v = Math.max(0, Math.min(100, Math.round(pct)));
        root.volume = v; // optimistic; the subscription confirms
        root._pendingVolume = v;
        if (!writeSoon.running)
            writeSoon.start();
    }

    function toggleMute() {
        root.muted = !root.muted;
        act.command = ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"];
        act.running = true;
    }

    function setSink(name) {
        root.sinkName = name;
        act.command = ["pactl", "set-default-sink", name];
        act.running = true;
        refreshSoon.restart();
    }

    // --- input actions ----------------------------------------------------
    function setInputVolume(pct) {
        const v = Math.max(0, Math.min(100, Math.round(pct)));
        root.inputVolume = v;
        root._pendingInputVolume = v;
        if (!writeSoon.running)
            writeSoon.start();
    }

    function toggleInputMute() {
        root.inputMuted = !root.inputMuted;
        act.command = ["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "toggle"];
        act.running = true;
    }

    function setSource(name) {
        root.sourceName = name;
        act.command = ["pactl", "set-default-source", name];
        act.running = true;
        refreshSoon.restart();
    }

    Process {
        id: act
        command: ["true"]
    }

    // Volume writes are coalesced. Dragging a slider produces a mouse event per
    // frame, and firing pactl at each one spawns processes faster than they
    // exit -- and `running = true` on an already-running Process is dropped, so
    // the last write can be lost and the real volume ends up behind the UI.
    // This keeps the newest value and issues one write per tick.
    property int _pendingVolume: -1
    property int _pendingInputVolume: -1

    Timer {
        id: writeSoon
        interval: 40
        onTriggered: {
            if (root._pendingVolume >= 0) {
                act.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", root._pendingVolume + "%"];
                act.running = true;
                root._pendingVolume = -1;
            } else if (root._pendingInputVolume >= 0) {
                act.command = ["pactl", "set-source-volume", "@DEFAULT_SOURCE@", root._pendingInputVolume + "%"];
                act.running = true;
                root._pendingInputVolume = -1;
            }
        }
    }

    Timer {
        id: refreshSoon
        interval: 250
        onTriggered: root.refresh()
    }

    // --- state ------------------------------------------------------------
    Process {
        id: query
        // One invocation, four answers, in a fixed order: default sink, default
        // source, sinks as JSON, sources as JSON. Separated by a marker line
        // because two JSON documents back to back cannot be split reliably.
        command: ["sh", "-c", "pactl get-default-sink; pactl get-default-source; echo '--MARK--'; pactl -f json list sinks; echo '--MARK--'; pactl -f json list sources"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("--MARK--");
                if (parts.length < 3)
                    return;

                const heads = parts[0].trim().split("\n");
                const defSink = (heads[0] || "").trim();
                const defSource = (heads[1] || "").trim();

                let sinkList = [];
                let sourceList = [];
                try {
                    sinkList = JSON.parse(parts[1]);
                    sourceList = JSON.parse(parts[2]);
                } catch (e) {
                    return; // a partial read is not worth acting on
                }

                const readVol = o => o.volume && o.volume["front-left"] ? parseInt(o.volume["front-left"].value_percent) || 0 : 0;

                const outs = [];
                for (const s of sinkList) {
                    const e = {
                        name: s.name,
                        description: s.description || s.name,
                        muted: !!s.mute,
                        volume: readVol(s),
                        active: s.name === defSink
                    };
                    outs.push(e);
                    if (e.active) {
                        root.volume = e.volume;
                        root.muted = e.muted;
                        root.sinkDescription = e.description;
                    }
                }

                const ins = [];
                for (const s of sourceList) {
                    // Every sink has a ".monitor" source that captures its own
                    // output. Those are not microphones and listing them as
                    // inputs is confusing, so they are dropped here -- the
                    // meter still uses one deliberately, further down.
                    if (s.monitor_source_name !== undefined && s.monitor_source_name !== null)
                        continue;
                    if (/\.monitor$/.test(s.name))
                        continue;
                    const e = {
                        name: s.name,
                        description: s.description || s.name,
                        muted: !!s.mute,
                        volume: readVol(s),
                        active: s.name === defSource
                    };
                    ins.push(e);
                    if (e.active) {
                        root.inputVolume = e.volume;
                        root.inputMuted = e.muted;
                        root.sourceDescription = e.description;
                    }
                }

                root.sinkName = defSink;
                root.sourceName = defSource;
                root.sinks = outs;
                root.sources = ins;
            }
        }
    }

    // Event-driven, not polled. A 1.5s poll meant pressing a volume key changed
    // the volume immediately and the bar caught up to a second and a half
    // later, which reads as the whole shell being laggy. pactl reports every
    // sink, source and server change as it happens.
    Process {
        id: events
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                // Client add/remove churn is every application opening a
                // stream; only device and server changes matter here.
                if (/on (sink|source|server)/.test(data))
                    coalesce.restart();
            }
        }
    }

    // A burst of events arrives for a single change. One refresh for the burst.
    Timer {
        id: coalesce
        interval: 30
        onTriggered: root.refresh()
    }

    // Backstop only. If the subscription ever dies the shell must not silently
    // freeze on stale numbers.
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // --- meters -----------------------------------------------------------
    // Restarted whenever the device changes, because parec is bound to the
    // device it was started against.
    readonly property string _levelScript: Quickshell.env("HOME") + "/.config/quickshell/audio-levels.sh"

    Process {
        id: outMeter
        // A sink's own output is metered through its ".monitor" source, which
        // is the one place a monitor source is the right answer.
        command: ["bash", root._levelScript, root.sinkName + ".monitor"]
        running: root.metering && root.sinkName !== ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.outputLevel = parseInt(data) || 0
        }
    }

    Process {
        id: inMeter
        command: ["bash", root._levelScript, root.sourceName]
        running: root.metering && root.sourceName !== ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.inputLevel = parseInt(data) || 0
        }
    }

    // Levels decay to zero when metering stops, so a stale bar is never left
    // frozen mid-scale on screen.
    onMeteringChanged: {
        if (!metering) {
            root.outputLevel = 0;
            root.inputLevel = 0;
        }
    }
}
