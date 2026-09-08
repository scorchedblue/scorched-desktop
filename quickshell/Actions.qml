pragma Singleton

// The palette's system actions -- everything besides launching an
// application: session commands, hardware toggles, switching an audio sink.
//
// Declared as data here, not built into Launcher.qml. Adding an action means
// adding an entry to `staticActions` (or a generator like `sinkActions`
// below), never touching the widget that renders the results.
//
// Matched with Apps.subsequence rather than a second copy of it: that
// function is a generic string-against-query scorer, nothing about it is
// application-specific.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    function run(cmd) {
        act.command = cmd;
        act.running = true;
    }

    Process {
        id: act
        command: ["true"]
    }

    readonly property var staticActions: [
        {
            name: "Lock session",
            comment: "swaylock",
            run: () => root.run(["swaylock", "-f"])
        },
        {
            name: "Toggle Wi-Fi",
            comment: "radio on/off",
            // nmcli has no "toggle" of its own -- read the current state and
            // flip it, same idea as screen-power.sh but one-shot rather than
            // idle-timer-safe, since this only ever runs from a keypress.
            run: () => root.run(["sh", "-c", "nmcli radio wifi | grep -q enabled && nmcli radio wifi off || nmcli radio wifi on"])
        },
        {
            name: "Toggle mute",
            comment: Audio.muted ? "unmute output" : "mute output",
            run: () => Audio.toggleMute()
        },
        {
            name: "Blank screen",
            comment: "monitors off",
            run: () => root.run(["bash", Quickshell.env("HOME") + "/.config/quickshell/screen-power.sh", "off"])
        },
        {
            name: "Suspend",
            comment: "sleep",
            run: () => root.run(["systemctl", "suspend"])
        },
        {
            name: "Log out",
            comment: "end session",
            // Hyprland 0.56 takes Lua here, not the old string dispatcher.
            run: () => root.run(["hyprctl", "dispatch", "hl.dsp.exit()"])
        },
        {
            name: "Restart",
            comment: "reboot",
            run: () => root.run(["systemctl", "reboot"])
        },
        {
            name: "Shut down",
            comment: "power off",
            run: () => root.run(["systemctl", "poweroff"])
        }
    ]

    // One entry per audio sink that is not already the default -- generated
    // from state Audio.qml already polls, not hardcoded, so a headset plugged
    // in mid-session is switchable from here the moment Audio.qml notices it.
    readonly property var sinkActions: Audio.sinks.filter(s => !s.active).map(s => ({
                name: "Switch audio output to " + s.description,
                comment: "",
                run: () => Audio.setSink(s.name)
            }))

    readonly property var all: staticActions.concat(sinkActions)

    function score(action, query) {
        if (query === "")
            return 1;

        const n = action.name.toLowerCase();

        if (n.startsWith(query))
            return 1000000 - n.length;

        let best = -1;

        const byName = Apps.subsequence(n, query);
        if (byName >= 0)
            best = 100000 + byName * 10;

        const byComment = Apps.subsequence(action.comment.toLowerCase(), query);
        if (byComment >= 0)
            best = Math.max(best, byComment);

        if (best < 0)
            return -1;

        return best - n.length;
    }

    // Scored, unsliced -- see Apps.scoredHits for why the merge needs these
    // unsliced and un-sorted-alone.
    function scoredHits(query) {
        const q = query.toLowerCase().trim();
        const hits = [];
        for (const a of root.all) {
            const s = score(a, q);
            if (s >= 0)
                hits.push({
                    action: a,
                    s: s
                });
        }
        return hits;
    }
}
