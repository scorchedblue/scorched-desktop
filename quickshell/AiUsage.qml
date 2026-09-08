pragma Singleton

// How much of the AI assistant's usage window is spent.
//
// The numbers come from ai-usage.sh, which is the only thing that touches a
// credential -- nothing here opens ~/.claude/.credentials.json, and no token
// ever reaches this process. This just parses the numbers that come back.
//
// The shape is a list of providers, each with a list of windows, because a
// second provider should be another entry rather than a rewrite. Nothing here
// is named after Anthropic.
//
// Unknown is a state, not a zero. Every percentage is -1 when it is not known,
// and every place that renders one has to decide what to say about that. A
// fabricated 0% reads as "plenty of headroom" at exactly the moment there is
// none, which is the failure this indicator exists to prevent.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Providers, exactly as the helper reported them. Empty means nothing is
    // configured on this machine -- which is not the same as "we could not
    // find out", and the bar hides itself for the first only.
    property var providers: []

    readonly property var primary: root.providers.length > 0 ? root.providers[0] : null
    readonly property bool available: root.primary !== null

    readonly property var session: root.windowById("session")
    readonly property var weekly: root.windowById("weekly")

    // -1 when unknown, never 0.
    readonly property real sessionPercent: root.percentOf(root.session)
    readonly property real weeklyPercent: root.percentOf(root.weekly)

    readonly property bool locked: root.primary ? root.primary.status === "locked" : false
    readonly property string lockedReason: {
        if (!root.primary || !root.primary.windows)
            return "";
        for (const w of root.primary.windows) {
            if (typeof w.lockedReason === "string" && w.lockedReason !== "")
                return w.lockedReason;
        }
        return "";
    }

    readonly property string providerName: root.primary && root.primary.name ? root.primary.name : ""
    readonly property string model: root.primary && root.primary.model ? root.primary.model : ""

    readonly property string _script: Quickshell.env("HOME") + "/.config/quickshell/ai-usage.sh"

    function windowById(id) {
        if (!root.primary || !root.primary.windows)
            return null;
        for (const w of root.primary.windows) {
            if (w.id === id)
                return w;
        }
        return null;
    }

    function percentOf(w) {
        return w && typeof w.percent === "number" ? w.percent : -1;
    }

    // "24%", or the word, because there is no honest number to show.
    function percentText(w) {
        const p = root.percentOf(w);
        return p < 0 ? "unknown" : Math.round(p) + "%";
    }

    // A reset an hour from now is a time; one four days out needs its day. Both
    // are local -- the endpoint answers in UTC and nobody plans in UTC.
    function resetText(w) {
        if (!w || typeof w.resetsAt !== "string" || w.resetsAt === "")
            return "unknown";
        const d = new Date(w.resetsAt);
        if (isNaN(d.getTime()))
            return "unknown";
        return d.toDateString() === new Date().toDateString() ? Qt.formatDateTime(d, "HH:mm") : Qt.formatDateTime(d, "ddd HH:mm");
    }

    function refresh() {
        if (!query.running)
            query.running = true;
    }

    // Keep the provider, forget its numbers. Used when a reply cannot be
    // parsed: that is a reading we do not have, not a reading of zero.
    function _forget(list) {
        return list.map(p => ({
                    id: p.id,
                    name: p.name,
                    status: "unknown",
                    model: p.model,
                    windows: (p.windows || []).map(w => ({
                            id: w.id,
                            label: w.label,
                            percent: null,
                            resetsAt: null,
                            lockedReason: null
                        }))
                }));
    }

    Process {
        id: query
        command: ["bash", root._script]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                let doc = null;
                try {
                    doc = JSON.parse(text);
                } catch (e) {
                    doc = null;
                }

                if (doc && Array.isArray(doc.providers))
                    root.providers = doc.providers;
                else if (root.providers.length > 0)
                    root.providers = root._forget(root.providers);
            }
        }
    }

    // Two minutes. A five-hour window does not move faster than that, and this
    // is an undocumented endpoint that does not need polling every second.
    // Opening the panel refreshes anyway, so the number you look at is fresh.
    Timer {
        interval: 120000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
