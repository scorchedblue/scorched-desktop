pragma Singleton

// The bar's arrangement: three ordered lists of item ids, and where they are
// kept.
//
// Bar.qml used to be three independently anchored children -- workspaces on the
// left, the clock centred, a Row of indicators on the right. Nothing could move
// between them because they were not one list. This singleton is the list. Every
// bar item is an id in exactly one zone, the bar renders each zone in order, and
// dragging an item only ever rewrites what is here.
//
// --- where this lives, and why ------------------------------------------------
//
// ~/.local/state/scorched/bar.conf, next to idle.conf.
//
//   * It is user state, not image state. This repository is deployed to every
//     account by chezmoi, so a layout committed here would be everybody's
//     layout and would be overwritten on the next deploy.
//   * ~/.config/quickshell *is* this repository's checkout on a live machine.
//     Writing there means the shell editing its own source, and the next
//     `just sync` -- which is `rsync --delete` -- throws the file away.
//   * XDG_STATE_HOME is the spec's home for "state that should persist between
//     restarts, but is not important enough to be in the config directory".
//     A bar arrangement is exactly that: losing it is an annoyance, not a
//     misconfiguration. ~/.local/state is on /var/home, so it also survives a
//     rebase into another bootc deployment.
//
// One arrangement for all monitors. Every screen builds its own Bar and they all
// read this, so dragging an item on one bar moves it on all of them. Per-monitor
// arrangements would need a monitor identity that is stable across a replug, and
// Hyprland's output names are not that.

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // The bar as this repository ships it. A machine whose bar.conf does not
    // exist ends up with exactly this -- see _adopt: an empty file contributes
    // nothing and every id is then appended to its default zone in this order.
    readonly property var defaults: ({
            left: ["workspaces"],
            centre: ["clock"],
            right: ["tray", "net", "ts", "bt", "audio", "display", "notifs", "ai", "sys", "power"]
        })

    readonly property var zones: ["left", "centre", "right"]

    property var left: root.defaults.left
    property var centre: root.defaults.centre
    property var right: root.defaults.right

    // Drives the reset control in the Displays popout: a reset that is offered
    // when there is nothing to reset reads as broken.
    readonly property bool customised: !root._same(root.left, root.defaults.left) || !root._same(root.centre, root.defaults.centre) || !root._same(root.right, root.defaults.right)

    readonly property string _dir: Quickshell.env("HOME") + "/.local/state/scorched"
    readonly property string _file: _dir + "/bar.conf"

    // Put `id` in `zone` immediately before `beforeId`, or at the end of the
    // zone if that is empty or not there. Named rather than numbered on purpose:
    // the bar decides where a drop lands from what is on screen, and a zone can
    // hold items that are not -- a numeric index would have to agree with the
    // bar about how many of those there were.
    //
    // Returns false and writes nothing when the arrangement would not change. A
    // drop is otherwise a file write and a rebuild of every delegate in the bar,
    // and a click that happened to cross the drag threshold should cost neither.
    function place(id, zone, beforeId) {
        if (root.zones.indexOf(zone) < 0)
            return false;

        const next = {
            left: root.left.filter(x => x !== id),
            centre: root.centre.filter(x => x !== id),
            right: root.right.filter(x => x !== id)
        };
        const at = beforeId ? next[zone].indexOf(beforeId) : -1;
        next[zone].splice(at < 0 ? next[zone].length : at, 0, id);

        if (root._same(next.left, root.left) && root._same(next.centre, root.centre) && root._same(next.right, root.right))
            return false;

        root.left = next.left;
        root.centre = next.centre;
        root.right = next.right;
        root.save();
        return true;
    }

    function reset() {
        root.left = root.defaults.left.slice();
        root.centre = root.defaults.centre.slice();
        root.right = root.defaults.right.slice();
        root.save();
    }

    function save() {
        // The zone contents go in as arguments, not spliced into the shell
        // string. They are ids from a fixed set today, but a layout file is the
        // one thing here whose contents a user can change, and building a shell
        // command out of it by concatenation is how that stops being safe.
        writer.command = ["sh", "-c", 'mkdir -p "$1" && printf "%s\\n" "$2" "$3" "$4" > "$1/bar.conf"', "sh", root._dir, "left " + root.left.join(" "), "centre " + root.centre.join(" "), "right " + root.right.join(" ")];
        writer.running = true;
    }

    function _same(a, b) {
        return a.length === b.length && a.every((x, i) => x === b[i]);
    }

    // Reconcile a file against what this shell actually has.
    //
    // Ids the shell does not know are dropped, so a layout written by a later
    // version cannot leave a hole in the bar. Ids the file does not mention are
    // appended to the zone they ship in, so an indicator added after the file
    // was written appears rather than silently going missing -- a saved layout
    // must not be able to hide part of the bar.
    function _adopt(found) {
        const known = root.defaults.left.concat(root.defaults.centre, root.defaults.right);
        const seen = [];
        const clean = list => list.filter(id => {
            if (known.indexOf(id) < 0 || seen.indexOf(id) >= 0)
                return false;
            seen.push(id);
            return true;
        });

        const next = {
            left: clean(found.left),
            centre: clean(found.centre),
            right: clean(found.right)
        };

        for (const zone of root.zones)
            for (const id of root.defaults[zone])
                if (seen.indexOf(id) < 0) {
                    next[zone].push(id);
                    seen.push(id);
                }

        // Assigning identical lists would still swap the array objects and
        // rebuild every delegate in every bar. On the common startup -- no file,
        // so this reconstructs the defaults -- that rebuild is for nothing.
        if (root._same(next.left, root.left) && root._same(next.centre, root.centre) && root._same(next.right, root.right))
            return;

        root.left = next.left;
        root.centre = next.centre;
        root.right = next.right;
    }

    function _parse(text) {
        const found = {
            left: [],
            centre: [],
            right: []
        };
        for (const line of text.split("\n")) {
            const f = line.trim().split(/\s+/).filter(s => s.length > 0);
            if (f.length > 0 && root.zones.indexOf(f[0]) >= 0)
                found[f[0]] = f.slice(1);
        }
        root._adopt(found);
    }

    Process {
        id: writer
        command: ["true"]
    }

    Process {
        id: reader
        // The trailing `echo` is load-bearing, the same as in Idle: on an
        // account that has never reordered anything the file does not exist,
        // cat produces nothing, and StdioCollector does not fire
        // onStreamFinished for an empty stream at all.
        command: ["sh", "-c", "cat '" + root._file + "' 2>/dev/null; echo"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
    }
}
