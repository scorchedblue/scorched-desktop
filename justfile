# scorched-desktop -- task runner.
#
# Nothing is built here. These recipes check the configuration and push it to a
# running ScorchedBlue VM, which is the development loop: config lives in $HOME,
# so it never needs an image rebuild to test.

# Where a test VM is reachable. The qemu invocation forwards this to the guest's
# port 22; see README.
vm_host := "test@localhost"
vm_port := "2222"

default:
    @just --list

setup:
    mise install
    git config core.hooksPath .githooks

fmt:
    stylua hypr/
    shfmt -w -i 4 -ci scripts/*.sh quickshell/*.sh

# quickshell/*.sh is included deliberately: the shell shells out for the things
# QML cannot do, and those helpers are as much a part of it as the QML is.
lint:
    stylua --check hypr/
    shfmt -d -i 4 -ci scripts/*.sh quickshell/*.sh
    shellcheck scripts/*.sh quickshell/*.sh

# Syntax-check the Lua. Hyprland only reports a bad config after the session
# fails to start, which is a slow and confusing way to find a typo.
check:
    #!/usr/bin/bash
    set -euo pipefail
    for f in hypr/*.lua; do
        luajit -e "local fn,err = loadfile('$f'); if not fn then io.stderr:write(err..'\n'); os.exit(1) end"
        echo "ok: $f"
    done

# Ask Hyprland itself whether it accepts the config, not merely whether the
# Lua parses. `check` only proves the Lua loads -- Hyprland rejects the whole
# file on a single unknown key, which is a session that never starts rather
# than a typo it complains about (see the `pseudotile` scar in
# hypr/hyprland.lua). This closes that gap with the flag Hyprland ships for
# exactly this purpose.
#
# Local-only, not part of `ci`: CI runs on a stock GitHub runner with no
# Hyprland installed. The ScorchedBlue image carries the right build but is
# not published yet, so CI cannot pull it (blocked on scorched-planning's
# P7). Installing Hyprland from the ashbuk COPR in CI was the other option --
# rejected because it pins a second copy of Hyprland that can drift from the
# image's own version. `sync` keeps depending on `check` alone so the
# edit-sync-look loop stays fast; run this by hand before trusting a config
# change, or against a VM/image that actually has Hyprland.
#
# Includes a control: a deliberately unknown key must be rejected, so a
# passing run demonstrates this check can fail, not merely that it passes.
verify-config:
    #!/usr/bin/bash
    set -euo pipefail
    if ! command -v Hyprland >/dev/null 2>&1; then
        echo "Hyprland is not installed -- this check only runs where Hyprland does (the VM or a ScorchedBlue image)" >&2
        exit 1
    fi
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime-$(id -u)}"
    mkdir -p "$XDG_RUNTIME_DIR"
    for f in hypr/*.lua; do
        Hyprland --verify-config -c "$f"
        echo "ok: $f"
    done
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    {
        cat hypr/hyprland.lua
        echo 'hl.config({ render = { cm_definitely_not_a_real_key = true } })'
    } >"$tmp/bogus.lua"
    if Hyprland --verify-config -c "$tmp/bogus.lua" >/dev/null 2>&1; then
        echo "control failed: Hyprland accepted an unknown config key" >&2
        exit 1
    fi
    echo "ok: control rejected an unknown key"

# Push config to a running VM and reload in place.
sync: check
    rsync -av --delete -e "ssh -p {{ vm_port }}" hypr/ {{ vm_host }}:.config/hypr/
    rsync -av --delete -e "ssh -p {{ vm_port }}" quickshell/ {{ vm_host }}:.config/quickshell/
    # hyprctl needs HYPRLAND_INSTANCE_SIGNATURE, which an ssh session does not
    # inherit from the graphical session. Derive it from the runtime dir.
    ssh -p {{ vm_port }} {{ vm_host }} \
        'export HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/$(id -u)/hypr/ 2>/dev/null | head -1); \
         [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && hyprctl reload' || \
        echo "reload failed -- is a Hyprland session running in the VM?"

# Fixture tests for the helper scripts' parsing. ai-usage.jq is the one worth
# pinning: an endpoint that changes shape must read as "unknown", never as 0%,
# and "we were careful" is not a guarantee of that.
# Every popout that can be opened must have a panel to show.
#
# This is a two-sided mapping: `Popouts.toggle(name, ...)` opens a popout, and
# `panelFor(name)` in Bar.qml decides what it renders. Nothing ties them
# together, so one side can be edited without the other -- which is exactly what
# happened in #16, where a restructure of Bar.qml carried the indicators across
# and left the panels behind. `ts` and `ai` kept their bar items and opened
# empty popouts, CI stayed green, and nothing could see it (#27).
#
# Grep rather than a QML test because it needs no Qt and no session: it runs in
# `ci` on a stock runner in milliseconds. Verified to discriminate -- run
# against the commit before the fix it reports `ai ts`.
verify-popouts:
    #!/usr/bin/bash
    set -euo pipefail
    openable="$(grep -rhoP 'Popouts\.toggle\("\K[a-z]+' quickshell/*.qml | sort -u)"
    renderable="$(sed -n '/function panelFor/,/^    }$/p' quickshell/Bar.qml \
        | grep -oP 'case "\K[a-z]+' | sort -u)"
    missing="$(comm -23 <(echo "$openable") <(echo "$renderable"))"
    if [ -n "$missing" ]; then
        echo "popouts that can be opened but have no panel:" >&2
        echo "$missing" | sed 's/^/  /' >&2
        echo "add a case to panelFor() in quickshell/Bar.qml" >&2
        exit 1
    fi
    echo "popouts: every openable name has a panel ($(echo "$openable" | wc -l) of them)"

unit:
    bash scripts/test-ai-usage.sh

# The QML files qmllint is allowed to read. Explicit, never a glob.
#
# This is the safety property of the whole recipe, not an inconvenience.
# `pragma ComponentBehavior: Bound` is required before qmllint can resolve
# `root.x` inside a nested Component -- and it is not a lint-only pragma. Under
# it a Repeater delegate can no longer read an implicitly-injected `modelData`
# or `index`, so a file whose delegates have not been converted to
# `required property` first comes up blank at runtime with nothing failing at
# load. The other 11 files with delegates carry 80 implicit reads between them.
#
# So a file joins this list only after its delegates are converted and the
# result has been looked at in a session. A glob would sweep in the other ten
# the moment someone added the pragma to make the lint pass, and the lint would
# go green over a shell with empty lists. Widen it one file at a time.
#
# Bar.qml is here because it already declares `required property` on both its
# own `modelData` and the bar-entry delegate's, which is what makes it the one
# file eligible today -- and it is the file the #12/#13 defect actually shipped
# in.
qmllint_files := "Bar.qml"

# Type-check the QML. Nothing else in this repository reads it: `lint` reads Lua
# and shell, `check` reads Lua, `unit` reads one jq filter, and SonarQube Cloud
# supports neither QML nor Lua. That is how five calls to a popout API deleted
# by #14 reached main green in #12 and #13.
#
# Runs in a container because both halves of the checker are missing here:
# qmllint ships in qt6-qtdeclarative-devel, which the image does not carry, and
# resolving a single Quickshell type needs Quickshell's own `.qmltypes`, which
# only a build of it produces. .ci/Containerfile assembles both. Fedora 44's Qt
# is 6.11.2, the same Qt the image ships, so the checker is not a second
# version of anything -- but the Quickshell pin in there is a second copy of the
# image's, and bumping one without the other lints against types the shell no
# longer runs on.
#
# Includes a control: a deliberately bogus member must be rejected as
# `missing-property`, so a passing run demonstrates this check can fail rather
# than merely that it passed.
qmllint:
    ./scripts/qmllint.sh {{ qmllint_files }}

test: lint check unit verify-popouts

# Full-history secret scan. The pre-commit hook runs `protect --staged`, which
# only ever sees one commit; this is what catches anything already landed.
secrets:
    gitleaks detect --no-banner --redact

# `qmllint` is here rather than in `test` on purpose: it wants podman and, on a
# cold cache, a few minutes to build Quickshell, which is the wrong price for
# the recipe people run while editing. `test` stays in the milliseconds.
ci: secrets test qmllint

# Must run from inside the ScorchedBlue graphical session, not over ssh from
# here: it reads the compositor's log out of /run and takes a screenshot,
# neither of which survives the session that produced them.
#
# Writes to ~/scorched-validation/<timestamp>/. That is on /var/home, so it is
# still there after rebooting into another deployment -- the evidence outlives
# the boot it came from, which is the whole point.
#
# Check a hardware session: NVIDIA, autostarts, portals, screenshot.
validate:
    ./scripts/validate-session.sh

# Screenshot the VM's session. qemu's `screendump` returns nothing under
# -display egl-headless, and grim runs inside the guest against the real
# compositor, so it captures what a user would actually see.
shot out="/tmp/scorched-vm.png":
    ssh -p {{ vm_port }} {{ vm_host }} \
        'export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1; grim /tmp/shot.png'
    scp -P {{ vm_port }} {{ vm_host }}:/tmp/shot.png {{ out }}
    @echo "wrote {{ out }}"
