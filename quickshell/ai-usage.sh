#!/usr/bin/bash
#
# Report AI assistant usage limits as JSON on stdout, one entry per provider.
#
#   { "providers": [ { "id": "claude", "name": "Claude",
#                      "status": "ok" | "locked" | "unknown",
#                      "model": "opus" | null,
#                      "windows": [ { "id": "session", "label": "Session",
#                                     "percent": 24.0,
#                                     "resetsAt": "2026-09-08T18:00:00Z",
#                                     "lockedReason": null } ] } ] }
#
# An empty provider list means nothing is configured on this machine, which is
# not the same as a provider whose numbers could not be read -- that is a
# provider with status "unknown". The shell hides the indicator for the first
# and shows "unknown" for the second.
#
# Why a script and not QML: the token lives in ~/.claude/.credentials.json, and
# the shell must never open that file. It calls this instead and receives only
# numbers, so no part of the QML ever holds a credential, and the parsing sits
# somewhere a test can reach it -- see scripts/test-ai-usage.sh.
#
# The issue asked for a `scorched` subcommand. That CLI ships from the image
# repository rather than this one, so this sits with the shell's other helpers;
# the property that mattered -- no credential handling in QML -- is the same.
#
# The token is never logged and never becomes a process argument: it is written
# into curl's stdin config, so it is absent from /proc/*/cmdline.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly here
readonly program="${here}/ai-usage.jq"

readonly endpoint="https://api.anthropic.com/api/oauth/usage"
readonly creds="${HOME}/.claude/.credentials.json"
readonly settings="${HOME}/.claude/settings.json"

# No provider at all, as opposed to a provider whose numbers are unknown. A
# machine that has never signed in should show nothing rather than a permanent
# question mark.
none() {
    printf '{"providers":[]}\n'
}

# Which model this account is set to use. The usage endpoint does not report it,
# so it comes from Claude Code's own settings, and stays null when unset rather
# than being guessed at.
current_model() {
    if [ -n "${ANTHROPIC_MODEL:-}" ]; then
        printf '%s' "$ANTHROPIC_MODEL"
        return 0
    fi
    [ -r "$settings" ] || return 0
    jq -r '.model // empty' "$settings" 2>/dev/null
}

# The first accessToken anywhere in the credentials file. Searched rather than
# read from a fixed path: the file belongs to another program, and a change to
# its nesting should cost this the token, not hand it a wrong string.
read_token() {
    [ -r "$creds" ] || return 0
    jq -r '.. | objects | select(has("accessToken")) | .accessToken
           | select(type == "string" and . != "")' "$creds" 2>/dev/null | head -1
}

fetch() {
    # --config - keeps the Authorization header off the command line. --fail
    # turns an HTTP error into no output, which the caller already treats as
    # unknown, so an expired token cannot become a reassuring number.
    printf 'header = "Authorization: Bearer %s"\n' "$1" |
        curl --silent --fail --max-time 10 --config - \
            --header "anthropic-beta: oauth-2025-04-20" \
            --header "anthropic-version: 2023-06-01" \
            --header "accept: application/json" \
            "$endpoint" 2>/dev/null
}

main() {
    local model token raw doc

    if ! command -v jq >/dev/null 2>&1 || [ ! -r "$program" ]; then
        none
        return 0
    fi

    model="$(current_model)"
    token="$(read_token)"
    if [ -z "$token" ]; then
        none
        return 0
    fi

    raw=""
    if command -v curl >/dev/null 2>&1; then
        raw="$(fetch "$token")"
    fi
    unset token

    doc="$(printf '%s' "$raw" | jq -c --arg model "$model" -f "$program" 2>/dev/null)"
    # An empty or unparseable body is mapped as `{}`, which is the same document
    # with every number null: unknown, never zero.
    [ -n "$doc" ] || doc="$(printf '{}' | jq -c --arg model "$model" -f "$program" 2>/dev/null)"
    if [ -z "$doc" ]; then
        none
        return 0
    fi

    printf '%s\n' "$doc"
}

main "$@"
