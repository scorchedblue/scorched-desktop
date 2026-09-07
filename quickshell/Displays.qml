pragma Singleton

// Monitor state, via hyprctl.
//
// This panel reports rather than controls, and that is deliberate. There is no
// backlight device on this class of machine -- `brightnessctl -l` lists only
// keyboard LEDs -- and changing an external monitor's brightness needs DDC/CI
// via ddcutil, which the image does not ship. Offering a brightness slider that
// silently does nothing would be worse than offering none.
//
// Refresh rate is the one thing here that genuinely can be set, so that is what
// this exposes.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var monitors: []

    function refresh() {
        query.running = true;
    }

    // No dpms control here, deliberately. `hyprctl dispatch dpms on|off` is a
    // parse error against a Lua config, and the Lua dispatcher `hl.dsp.dpms()`
    // IGNORES its argument and toggles -- verified by calling the same form
    // twice and watching the state alternate. A control that cannot be told
    // which state to reach can strand a user looking at a black screen, so
    // there is none.

    // Apply a mode.
    //
    // This has to go through `hyprctl eval` and the Lua API. `hyprctl keyword`
    // is the answer everywhere on the internet and it does not work here at
    // all -- against a Lua config it refuses outright with "keyword can't work
    // with non-legacy parsers. Use eval." It fails loudly, at least.
    //
    // position and scale stay "auto" to match what the config sets, rather than
    // pinning the values that happen to be current.
    function setMode(name, width, height, rate) {
        const lua = 'hl.monitor({ output = "' + name + '", mode = "' + width + "x" + height + "@" + rate + '", position = "auto", scale = "auto" })';
        act.command = ["hyprctl", "eval", lua];
        act.running = true;
        refreshSoon.restart();
    }

    // Back to the automatic choice. "highres" and not "highrr", matching what
    // hyprland.lua sets at session start -- if these two disagreed, "Auto" would
    // put the monitor somewhere the session would never have chosen itself.
    function setAutoMode(name) {
        const lua = 'hl.monitor({ output = "' + name + '", mode = "highres", position = "auto", scale = "auto" })';
        act.command = ["hyprctl", "eval", lua];
        act.running = true;
        refreshSoon.restart();
    }

    Process {
        id: act
        command: ["true"]
    }

    Timer {
        id: refreshSoon
        interval: 250
        onTriggered: root.refresh()
    }

    Process {
        id: query
        command: ["hyprctl", "monitors", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const out = [];
                for (const m of list) {
                    out.push({
                        name: m.name,
                        // hyprctl's description carries maker, model and serial.
                        // The serial is not something to put on screen, so keep
                        // the first two words and drop the trailing hash.
                        description: (m.description || "").replace(/\s*#\S+\s*$/, ""),
                        width: m.width,
                        height: m.height,
                        refresh: Math.round(m.refreshRate || 0),
                        scale: m.scale,
                        x: m.x,
                        y: m.y,
                        focused: !!m.focused,
                        dpms: !!m.dpmsStatus,
                        workspace: m.activeWorkspace ? m.activeWorkspace.name : "",
                        // "3840x1600@144.00Hz" -> a structured, de-duplicated
                        // list of the modes at this monitor's current
                        // resolution. Offering every resolution as well would
                        // turn a refresh-rate picker into a mode editor.
                        rates: (function () {
                            const seen = {};
                            const out = [];
                            for (const s of (m.availableModes || [])) {
                                const parts = s.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
                                if (!parts)
                                    continue;
                                if (parseInt(parts[1]) !== m.width || parseInt(parts[2]) !== m.height)
                                    continue;
                                const hz = Math.round(parseFloat(parts[3]));
                                if (seen[hz])
                                    continue;
                                seen[hz] = true;
                                out.push(hz);
                            }
                            out.sort((a, b) => b - a);
                            return out;
                        })()
                    });
                }
                root.monitors = out;
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
