pragma Singleton

// Idle behaviour: blank the monitors after a while, optionally lock too.
//
// The shell owns swayidle rather than Hyprland's autostart, because a thing you
// can switch off has to be owned by something that is still running when it is
// off. Started from the compositor config, the only way to stop locking was to
// kill a process by hand.
//
// Blanking goes through screen-power.sh, never `hyprctl dispatch dpms` directly.
// Hyprland 0.56 offers no way to command a DPMS state -- every documented form
// ignores its argument and toggles -- so that script reads the current state and
// toggles only when it differs. That matters most here: an idle daemon can fire
// resume more than once, and a bare toggle would turn the screen back off.
//
// Choices are persisted. A setting that silently reverts is worse than none.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Blanking on by default; locking off. A desktop that nobody carries around
    // still wants its monitors to sleep, and mostly does not want a password
    // prompt for walking to the kitchen.
    property bool blankEnabled: true
    property int blankMinutes: 15

    property bool lockEnabled: false
    property int lockMinutes: 10

    property bool loaded: false

    readonly property string _dir: Quickshell.env("HOME") + "/.local/state/scorched"
    readonly property string _file: _dir + "/idle.conf"
    readonly property string _screenPower: Quickshell.env("HOME") + "/.config/quickshell/screen-power.sh"

    // --- actions ----------------------------------------------------------
    function lockNow() {
        run(["swaylock", "-f"]);
    }

    function blankNow() {
        run(["bash", root._screenPower, "off"]);
    }

    function wake() {
        run(["bash", root._screenPower, "on"]);
    }

    function setBlankEnabled(on) {
        root.blankEnabled = on;
        save();
    }
    function setLockEnabled(on) {
        root.lockEnabled = on;
        save();
    }
    function setBlankMinutes(m) {
        root.blankMinutes = m;
        save();
    }
    function setLockMinutes(m) {
        root.lockMinutes = m;
        save();
    }

    function run(cmd) {
        act.command = cmd;
        act.running = true;
    }

    function save() {
        writer.command = ["sh", "-c", "mkdir -p '" + root._dir + "' && printf '%s %d %s %d\n' " + (root.blankEnabled ? "blank" : "noblank") + " " + root.blankMinutes + " " + (root.lockEnabled ? "lock" : "nolock") + " " + root.lockMinutes + " > '" + root._file + "'"];
        writer.running = true;
    }

    Process {
        id: act
        command: ["true"]
    }
    Process {
        id: writer
        command: ["true"]
    }

    // Load before starting anything, so a session where blanking was turned off
    // does not blank once on login before the setting is read.
    Process {
        id: loader
        // The trailing `echo` is load-bearing. On a fresh account the state file
        // does not exist, cat produces nothing, and StdioCollector does not fire
        // onStreamFinished for an empty stream at all -- so `loaded` never
        // became true, the gate below never opened, and the screen never
        // blanked until the user happened to change a setting. One newline is
        // enough to make the stream real.
        command: ["sh", "-c", "cat '" + root._file + "' 2>/dev/null; echo"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(/\s+/);
                if (f.length >= 4) {
                    root.blankEnabled = f[0] === "blank";
                    root.blankMinutes = parseInt(f[1]) || root.blankMinutes;
                    root.lockEnabled = f[2] === "lock";
                    root.lockMinutes = parseInt(f[3]) || root.lockMinutes;
                }
                root.loaded = true;
            }
        }
    }

    // swayidle's schedule comes from argv and cannot be changed while it runs,
    // so the process is rebuilt whenever any of this changes. Binding `command`
    // to the properties does exactly that.
    readonly property var _args: {
        const a = ["swayidle", "-w"];
        if (root.lockEnabled) {
            a.push("timeout", String(root.lockMinutes * 60), "swaylock -f");
        }
        if (root.blankEnabled) {
            a.push("timeout", String(root.blankMinutes * 60), "bash '" + root._screenPower + "' off");
            // resume fires on any input. screen-power.sh is idempotent, so
            // firing it repeatedly is harmless -- which is the whole reason it
            // reads before it toggles.
            a.push("resume", "bash '" + root._screenPower + "' on");
        }
        return a;
    }

    Process {
        id: idle
        // Nothing to schedule means nothing to run.
        running: root.loaded && (root.blankEnabled || root.lockEnabled)
        command: root._args
    }
}
