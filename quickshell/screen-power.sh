#!/usr/bin/bash
#
# Turn the monitors on or off, idempotently.
#
#   screen-power.sh on       # ensure on,  no-op if already on
#   screen-power.sh off      # ensure off, no-op if already off
#   screen-power.sh toggle
#   screen-power.sh status   # prints "on" or "off"
#
# Why this exists: Hyprland 0.56 gives no way to *command* a DPMS state.
#
#   hyprctl dispatch dpms off          -> parse error; the pre-Lua syntax is gone
#   hyprctl dispatch 'hl.dsp.dpms("on")'      -> toggles, argument ignored
#   hyprctl dispatch 'hl.dsp.dpms({state="on"})' -> toggles, argument ignored
#   hyprctl dispatch 'hl.dsp.dpms({on=true})'    -> toggles, argument ignored
#
# All three were checked by calling the same form twice and watching the state
# alternate. A bare toggle on an idle timer is dangerous: miss one edge and the
# screen stays dark after the user comes back.
#
# So: read the state first, and toggle only when it differs from the one asked
# for. That builds a reliable "set" out of an unreliable "toggle", and makes
# repeated calls harmless -- which is what an idle daemon needs, since it may
# fire resume more than once.
#
# The toggle applies to every monitor; the dispatcher ignores a monitor argument
# too. On a multi-head setup this is all-or-nothing.

set -uo pipefail

want="${1:-status}"

current() {
    # dpmsStatus is true when the display is ON.
    if hyprctl monitors -j 2>/dev/null | jq -e 'any(.[]; .dpmsStatus)' >/dev/null 2>&1; then
        echo on
    else
        echo off
    fi
}

toggle() {
    hyprctl dispatch 'hl.dsp.dpms({})' >/dev/null 2>&1
}

case "$want" in
    status)
        current
        ;;
    toggle)
        toggle
        ;;
    on | off)
        [ "$(current)" = "$want" ] && exit 0
        toggle
        # Confirm, and try once more if the compositor did not settle. Not a
        # retry loop: two attempts, then give up rather than strobe the display.
        sleep 0.4
        if [ "$(current)" != "$want" ]; then
            toggle
        fi
        ;;
    *)
        echo "usage: screen-power.sh on|off|toggle|status" >&2
        exit 2
        ;;
esac
