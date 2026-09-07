pragma Singleton

// The application list, and the fuzzy matcher over it.
//
// Entries come from apps.sh rather than Quickshell's DesktopEntries service,
// which finds nothing at all on this system -- see that script's header.
//
// Scanned once at startup and again when the launcher opens. Desktop files
// change when something is installed, which is rare and never while the user is
// mid-keystroke, so watching them would cost more than it is worth.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var all: []
    property bool loaded: false

    function refresh() {
        scan.running = true;
    }

    function launch(app) {
        // Terminal=true entries are console programs. Launching one without a
        // terminal starts a process with nowhere to draw and it vanishes.
        const cmd = app.terminal ? ["foot", "-e", "sh", "-c", app.exec] : ["sh", "-c", app.exec];
        runner.command = cmd;
        runner.running = true;
    }

    Process {
        id: runner
        command: ["true"]
    }

    Process {
        id: scan
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/apps.sh"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const f = line.split("\t");
                    if (f.length < 5)
                        continue;
                    out.push({
                        name: f[0],
                        exec: f[1],
                        comment: f[2],
                        terminal: f[3] === "true",
                        id: f[4],
                        // Folded to lower case once at scan time rather than
                        // on every keystroke against every entry.
                        lname: f[0].toLowerCase(),
                        lcomment: f[2].toLowerCase(),
                        lid: f[4].toLowerCase()
                    });
                }
                root.all = out;
                root.loaded = true;
            }
        }
    }

    // --- fuzzy matching ---------------------------------------------------
    //
    // Subsequence matching, the same idea as every fuzzy finder: the query
    // characters must appear in order but need not be adjacent, so "ff" finds
    // Firefox and "gimg" finds GNOME Image Viewer.
    //
    // Each field is matched SEPARATELY and the best result wins. The obvious
    // implementation -- concatenate name, comment and id into one haystack --
    // is wrong in a way that looks fine until you test it: a subsequence is
    // then free to span the join, so "ff" matched "Foot" by taking one f from
    // the name and one from the id, and "zzzz" matched "Zoom" by taking two z
    // from each. Firefox came third behind two applications with a single f in
    // their name.
    //
    // Scoring exists to make the *first* result right, which matters much more
    // than which results appear at all. Consecutive runs and word starts score
    // heavily, because that is what separates a real abbreviation from letters
    // that happen to be scattered through a phrase.
    function subsequence(text, query) {
        let ti = 0;
        let total = 0;
        let run = 0;

        for (let qi = 0; qi < query.length; qi++) {
            const c = query[qi];
            let found = -1;
            while (ti < text.length) {
                if (text[ti] === c) {
                    found = ti;
                    break;
                }
                ti++;
            }
            if (found < 0)
                return -1; // a missing character means no match at all

            let points = 1;
            // Start of a word: the initials people actually type.
            if (found === 0 || text[found - 1] === " " || text[found - 1] === "-" || text[found - 1] === "." || text[found - 1] === "_")
                points += 8;
            // Adjacent to the previous match: a real substring, not scatter.
            if (run > 0 && found === ti)
                points += 5;

            total += points;
            run++;
            ti = found + 1;
        }
        return total;
    }

    function score(app, query) {
        if (query === "")
            return 1;

        const n = app.lname;

        // An exact prefix of the name beats everything else outright.
        if (n.startsWith(query))
            return 1000000 - n.length;

        // Weighted by field, and never across them. A name match must always
        // outrank a comment match, however well the comment happens to score --
        // comments are prose and prose matches almost anything.
        let best = -1;

        const byName = subsequence(n, query);
        if (byName >= 0)
            best = 100000 + byName * 10;

        const byId = subsequence(app.lid, query);
        if (byId >= 0)
            best = Math.max(best, 10000 + byId * 6);

        const byComment = subsequence(app.lcomment, query);
        if (byComment >= 0)
            best = Math.max(best, byComment);

        if (best < 0)
            return -1;

        // Shorter names win ties: "cal" should offer Calculator before
        // Calendar Importer.
        return best - n.length;
    }

    function search(query) {
        const q = query.toLowerCase().trim();
        const hits = [];
        for (const app of root.all) {
            const s = score(app, q);
            if (s >= 0)
                hits.push({
                    app: app,
                    s: s
                });
        }
        hits.sort((a, b) => b.s - a.s || a.app.name.localeCompare(b.app.name));
        return hits.slice(0, 12).map(x => x.app);
    }
}
