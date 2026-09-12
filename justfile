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
unit:
    bash scripts/test-ai-usage.sh

test: lint check unit

# Full-history secret scan. The pre-commit hook runs `protect --staged`, which
# only ever sees one commit; this is what catches anything already landed.
secrets:
    gitleaks detect --no-banner --redact

ci: secrets test

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
