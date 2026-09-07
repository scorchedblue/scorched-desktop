#!/usr/bin/bash
#
# List launchable desktop entries, one per line, tab separated:
#
#   name <TAB> exec <TAB> comment <TAB> terminal <TAB> id
#
# Quickshell 0.3.1 ships a DesktopEntries service and on this system it finds
# nothing at all -- `applications.values.length` is 0 and `byId("foot")` returns
# null, with 77 desktop files present and XDG_DATA_DIRS set correctly. Rather
# than build a launcher on a service that reports an empty world, this reads the
# files directly.
#
# Only the [Desktop Entry] section is read. Desktop files also carry
# [Desktop Action ...] sections with their own Name and Exec keys, and a naive
# grep happily returns those, which is how launchers end up listing "New Window"
# as though it were an application.

set -uo pipefail

# Later directories win, matching XDG precedence: a user's own entry with the
# same basename replaces the system one rather than appearing twice.
dirs=()
IFS=: read -ra parts <<<"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
for p in "${parts[@]}"; do
    [ -n "$p" ] && dirs+=("$p/applications")
done
dirs+=("${XDG_DATA_HOME:-$HOME/.local/share}/applications")

# The files are passed to awk as arguments, not piped in. Piping a list of
# filenames makes awk read the *names* as its input, so FILENAME is empty and
# FNR never resets -- the per-file logic below silently never runs.
files=()
for d in "${dirs[@]}"; do
    [ -d "$d" ] || continue
    # -L because flatpak exports each application as a *symlink*. Without it,
    # -type f skips every flatpak on the system -- 47 missing applications here,
    # and no error anywhere to say so.
    while IFS= read -r f; do
        files+=("$f")
    done < <(find -L "$d" -maxdepth 2 -name '*.desktop' -type f 2>/dev/null)
done

[ ${#files[@]} -eq 0 ] && exit 0

awk -F= '
    FNR == 1 {
        # Flush the previous file before starting the next one.
        if (emit()) { }
        insection = 0; name = ""; exec = ""; comment = ""
        term = "false"; nodisplay = "false"; hidden = "false"; tryexec = ""
        # Reset per file too, or a single Type=Link entry rejects every entry
        # parsed after it.
        type = ""
        id = FILENAME
        sub(/^.*\//, "", id)
        sub(/\.desktop$/, "", id)
    }

    /^\[/ {
        # Only the first [Desktop Entry] counts; every later section is an
        # action, and its keys must not leak into the entry.
        insection = ($0 == "[Desktop Entry]")
        next
    }

    !insection { next }

    {
        key = $1
        # Values can contain "=", so rejoin everything after the first one.
        val = $0
        sub(/^[^=]*=/, "", val)
    }

    key == "Name" && name == ""       { name = val }
    key == "Comment" && comment == "" { comment = val }
    key == "Exec" && exec == ""       { exec = val }
    key == "Terminal"                 { term = tolower(val) }
    key == "NoDisplay"                { nodisplay = tolower(val) }
    key == "Hidden"                   { hidden = tolower(val) }
    key == "TryExec"                  { tryexec = val }
    key == "Type"                     { type = val }

    END { if (emit()) { } }

    function emit(  cmd) {
        if (name == "" || exec == "") return 0
        if (nodisplay == "true" || hidden == "true") return 0
        if (type != "" && type != "Application") return 0

        # Field codes are placeholders for files and URLs the launcher would
        # pass in. Nothing is being passed, so they must be removed rather than
        # handed to the shell as literal "%U".
        cmd = exec
        gsub(/%[fFuUdDnNickvm]/, "", cmd)
        gsub(/[ \t]+$/, "", cmd)

        printf "%s\t%s\t%s\t%s\t%s\n", name, cmd, comment, term, id
        return 1
    }
' "${files[@]}" | sort -u -t'	' -k1,1
