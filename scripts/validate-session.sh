#!/usr/bin/bash
#
# Post-boot validation for a ScorchedBlue Hyprland session.
#
# Run this from inside a graphical session on the hardware. It captures the
# whole verdict in one pass and writes it to a directory under $HOME, which is
# on /var/home and therefore survives a reboot into another deployment -- so
# the evidence can be read afterwards rather than remembered.
#
# Deliberately does not `set -e`. Every check here is expected to be able to
# fail; a failing check is a result, not a reason to stop collecting.

# `capsh` and `check` hand a single-quoted script to a child shell on purpose:
# the expansions inside must happen there, at check time, not here.
# shellcheck disable=SC2016

set -uo pipefail

out="${1:-$HOME/scorched-validation/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$out"

log="$out/report.md"
pass=0
fail=0

# Everything printed goes to the terminal and to report.md at once.
say() { printf '%s\n' "$*" | tee -a "$log"; }

# Run a command, capturing stdout and stderr to both.
cap() { "$@" 2>&1 | tee -a "$log"; }

# Same, for anything that needs a pipeline or a glob.
capsh() { bash -c "$1" 2>&1 | tee -a "$log"; }

# Fenced variants, since every capture below is inside a code block.
fence() {
    say '```'
    "$@"
    say '```'
}

check() {
    # check <description> <command...>
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        say "- PASS  $desc"
        pass=$((pass + 1))
    else
        say "- FAIL  $desc"
        fail=$((fail + 1))
    fi
}

# Boot start as a unix timestamp, for scoping coredumpctl to this boot only.
boot_epoch="$(date -d "$(uptime -s)" +%s)"

say "# ScorchedBlue session validation"
say
say "Captured: $(date -Is)"
say "Kernel:   $(uname -r)"
say "Boot ID:  $(cat /proc/sys/kernel/random/boot_id)"
say

# --- what image is this actually -------------------------------------------
say "## Deployment"
say
fence cap rpm-ostree status
say
say "Kernel command line:"
fence capsh "tr ' ' '\n' < /proc/cmdline"
say

# --- the four kargs the black-screen fix added ------------------------------
say "## NVIDIA kernel arguments"
say
say "Absent, nouveau binds the GPU from the initrd and nvidia.ko cannot attach:"
say "no DRM device for the compositor, no usable console for the VTs."
say
for karg in rd.driver.blacklist=nouveau modprobe.blacklist=nouveau \
    nvidia-drm.modeset=1 initcall_blacklist=simpledrm_platform_driver_init; do
    check "karg present: $karg" grep -qw -- "$karg" /proc/cmdline
done
check "nouveau is NOT loaded" capsh '! lsmod | grep -q "^nouveau"'
check "nvidia_drm is loaded" capsh 'lsmod | grep -q "^nvidia_drm"'
check "a DRM card node exists" capsh 'ls /dev/dri/card* >/dev/null 2>&1'
# /sys/module/nvidia_drm/parameters/modeset is 0400, so it cannot be read
# unprivileged and is useless as a check. A card bound to the nvidia driver
# with a connected connector proves the same thing and proves it harder: the
# driver reached the GPU *and* a display is live on it.
check "a DRM card is bound to the nvidia driver" capsh \
    'for c in /sys/class/drm/card*; do
         [ "$(basename "$(readlink -f "$c/device/driver" 2>/dev/null)")" = nvidia ] && exit 0
     done; exit 1'
check "an nvidia connector is connected" capsh \
    'for c in /sys/class/drm/card*/device/driver; do
         [ "$(basename "$(readlink -f "$c")")" = nvidia ] || continue
         card="$(basename "$(dirname "$(dirname "$c")")")"
         grep -qx connected /sys/class/drm/"$card"-*/status 2>/dev/null && exit 0
     done; exit 1'
say
say "DRM devices:"
fence capsh 'ls -l /dev/dri/'
say "Card to driver:"
fence capsh 'for c in /sys/class/drm/card*; do
                 [ -e "$c/device/driver" ] || continue
                 echo "$(basename "$c") -> $(basename "$(readlink -f "$c/device/driver")")"
             done'
say "Connector status:"
fence capsh 'for s in /sys/class/drm/card*-*/status; do
                 echo "$(basename "$(dirname "$s")"): $(cat "$s")"
             done'
say

# --- the autostart fix: all five children of hyprland.start -----------------
say "## Autostarts (the f4065d6 fix)"
say
say "All five now start from the \`hyprland.start\` event. As top-level"
say "\`hl.exec_cmd()\` calls they ran before WAYLAND_DISPLAY existed and every"
say "one of them died at login -- Quickshell loudest, via qFatal() and SIGABRT."
say
for proc in quickshell mako lxpolkit swaybg swayidle; do
    check "running: $proc" pgrep -x "$proc"
done
say
say "Process detail:"
fence capsh "pgrep -a -x 'quickshell|mako|lxpolkit|swaybg|swayidle'"
say

# --- did anything abort -----------------------------------------------------
say "## Coredumps this boot"
say
fence cap coredumpctl --since=@"$boot_epoch" list --no-legend
check "no coredumps this boot" capsh \
    "! coredumpctl --since=@$boot_epoch list --no-legend >/dev/null 2>&1"
say

# --- systemd ----------------------------------------------------------------
say "## Failed units"
say
say "System:"
fence cap systemctl --failed --no-pager --no-legend
say "User:"
fence cap systemctl --user --failed --no-pager --no-legend
# systemd-remount-fs fails the same way on any ostree system: the root is an
# overlay, and `mount -o remount /` returns "No changes allowed in reconfigure".
# It is inherited from the bootc base, not something this image introduced, so
# it is excluded by name rather than left to fail every run and train the eye
# to ignore the whole check. Anything else failing is ours.
ignored_units='systemd-remount-fs.service'
say "Ignoring, as inherited from the base: \`$ignored_units\`"
say
check "no failed system units beyond the inherited one" capsh \
    "[ -z \"\$(systemctl --failed --no-pager --no-legend 2>/dev/null \
                | grep -vE '$ignored_units')\" ]"
check "zero failed user units" capsh \
    '[ -z "$(systemctl --user --failed --no-pager --no-legend 2>/dev/null)" ]'
say

# --- Hyprland ---------------------------------------------------------------
say "## Hyprland"
say
runtime="/run/user/$(id -u)"
sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
if [ -z "$sig" ]; then
    # An ssh session does not inherit this from the graphical session.
    sig="$(find "$runtime/hypr" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | head -1)"
fi
export HYPRLAND_INSTANCE_SIGNATURE="$sig"
say "Instance: ${sig:-<none found>}"
say
check "hyprctl answers" hyprctl version

hyprlog="${sig:+$runtime/hypr/$sig/hyprland.log}"
if [ -n "$sig" ] && [ -r "$hyprlog" ]; then
    # The log lives in /run and is gone after reboot. This is the only chance
    # to keep it -- and it is where Quickshell's own stderr lands, since the
    # shell is a child of the compositor rather than a systemd unit.
    cp "$hyprlog" "$out/hyprland.log"
    say "Log copied to \`hyprland.log\` ($(wc -l <"$hyprlog") lines)."
    say
    say "Renderer -- llvmpipe here would mean the NVIDIA path is not being used:"
    fence capsh "grep -iE 'renderer|GL Vendor|EGL' '$hyprlog' | head -20"
    say
    say "Errors:"
    fence capsh "grep -iE 'err|crit|fail' '$hyprlog' | head -40"
    check "no EGL failures in the Hyprland log" capsh \
        "! grep -qiE 'eglInitialize errored|EGL_BAD_ALLOC' '$hyprlog'"
    check "not falling back to llvmpipe" capsh \
        "! grep -qi 'llvmpipe' '$hyprlog'"
else
    say "No readable Hyprland log (${hyprlog:-no instance signature found})."
    fail=$((fail + 1))
fi
say
say "Monitors:"
fence cap hyprctl monitors
say "Workspaces:"
fence cap hyprctl workspaces
say

# --- what the user would actually see ---------------------------------------
say "## Screenshot"
say
if grim "$out/session.png" 2>>"$log"; then
    say "Wrote \`session.png\` ($(du -h "$out/session.png" | cut -f1))."
    say
    say "The bar is the thing to look at: 32px tall, #1e1e2e, workspace pills"
    say "on the left, \`ddd d MMM  h:mm AP\` clock centred."
    pass=$((pass + 1))
else
    say "grim failed -- see report for its error."
    fail=$((fail + 1))
fi
say

# --- portals: one of the three reasons the pivot happened -------------------
say "## Portals"
say
say "Available backends:"
fence capsh 'ls /usr/share/xdg-desktop-portal/portals/'
say "portals.conf:"
fence capsh 'cat /etc/xdg-desktop-portal/portals.conf'
# xdg-desktop-portal.service is Requisite=graphical-session.target, which
# Hyprland does not start on its own -- see hyprland-session.target in the
# image. Check the target first: it is the cause, and the portal failure is
# only the symptom.
check "graphical-session.target is active" \
    systemctl --user is-active --quiet graphical-session.target
say
# "Is the portal running" is the wrong question -- portals are D-Bus activated
# and are legitimately absent until something asks. Asking is the test. This
# call both activates the portal and proves it answers.
say "ScreenCast portal (this activates it):"
fence capsh 'timeout 20 busctl --user call org.freedesktop.portal.Desktop \
    /org/freedesktop/portal/desktop org.freedesktop.DBus.Properties \
    Get ss org.freedesktop.portal.ScreenCast version'
check "ScreenCast portal answers" capsh \
    'timeout 20 busctl --user call org.freedesktop.portal.Desktop \
        /org/freedesktop/portal/desktop org.freedesktop.DBus.Properties \
        Get ss org.freedesktop.portal.ScreenCast version >/dev/null 2>&1'
say
say "Source types (7 = monitor|window|virtual) and cursor modes:"
fence capsh 'busctl --user get-property org.freedesktop.portal.Desktop \
    /org/freedesktop/portal/desktop org.freedesktop.portal.ScreenCast \
    AvailableSourceTypes AvailableCursorModes'
say
say "Running after activation:"
fence capsh 'pgrep -af "libexec/xdg-desktop-portal"'
# The hyprland backend is the one that carries the region picker; gtk does not
# implement ScreenCast at all, so if hyprland is absent, region sharing is too.
check "hyprland portal backend running" pgrep -f 'libexec/xdg-desktop-portal-hyprland'
say

# --- journals, for anything the checks above did not think to ask -----------
journalctl -b --no-pager >"$out/journal-system.txt" 2>&1
journalctl -b --user --no-pager >"$out/journal-user.txt" 2>&1

say "---"
say
say "**$pass passed, $fail failed.**"
say
say "Artifacts:"
say
for f in "$out"/*; do say "- \`$(basename "$f")\`"; done

printf '\n==> %s\n' "$out"
[ "$fail" -eq 0 ]
