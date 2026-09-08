#!/usr/bin/bash
#
# Fixture tests for quickshell/ai-usage.jq, the mapping behind the AI usage
# indicator.
#
# What is being pinned is one property: a response the mapping does not
# understand must come out as "unknown" with null percentages, never as 0%. The
# endpoint is undocumented and internal, so it will change shape one day without
# telling anyone, and on that day the indicator must say it does not know rather
# than report a comfortable number. That is not something to leave to care.
#
# No framework: bash and jq, both of which the lint and the shell already need.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly here
readonly program="${here}/../quickshell/ai-usage.jq"

failures=0

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required" >&2
    exit 2
fi

# map <fixture-json> <model> <query> -> the query's value
map() {
    printf '%s' "$1" | jq -r --arg model "$2" -f "$program" 2>&1 | jq -r "$3" 2>&1
}

# expect <description> <fixture> <model> <query> <expected>
expect() {
    local got
    got="$(map "$2" "$3" "$4")"
    if [ "$got" = "$5" ]; then
        printf 'ok    %s\n' "$1"
    else
        printf 'FAIL  %s\n        %s\n        want %s\n        got  %s\n' "$1" "$4" "$5" "$got"
        failures=$((failures + 1))
    fi
}

normal='{"five_hour":{"utilization":24.0,"resets_at":"2026-09-08T18:00:00Z","locked_reason":null},
         "seven_day":{"utilization":20.0,"resets_at":"2026-09-12T00:00:00Z","locked_reason":null},
         "nimbus_quill":1,"iguana_necktie":"x"}'
locked='{"five_hour":{"utilization":100,"resets_at":"2026-09-08T18:00:00Z","locked_reason":"usage_limit_reached"},
         "seven_day":{"utilization":88,"resets_at":"2026-09-12T00:00:00Z","locked_reason":null}}'
# What the script feeds the mapping when the request fails or the body is not
# JSON at all.
failed='{}'
# The endpoint renamed everything, which it is entitled to do.
reshaped='{"windows":[{"name":"five_hour","pct":24}]}'
# An error body still parses as JSON, and must not read as healthy.
errored='{"error":{"type":"authentication_error","message":"..."}}'
# A real zero is a real number and must survive as one.
fresh='{"five_hour":{"utilization":0,"resets_at":"2026-09-08T18:00:00Z","locked_reason":null},
        "seven_day":{"utilization":0,"resets_at":"2026-09-12T00:00:00Z","locked_reason":null}}'

expect "normal: status" "$normal" opus '.providers[0].status' 'ok'
expect "normal: provider id" "$normal" opus '.providers[0].id' 'claude'
expect "normal: model" "$normal" opus '.providers[0].model' 'opus'
expect "normal: window ids" "$normal" opus '[.providers[0].windows[].id]|join(",")' 'session,weekly'
expect "normal: session pct" "$normal" opus '.providers[0].windows[0].percent' '24.0'
expect "normal: weekly pct" "$normal" opus '.providers[0].windows[1].percent' '20.0'
expect "normal: session reset" "$normal" opus '.providers[0].windows[0].resetsAt' '2026-09-08T18:00:00Z'
expect "normal: weekly reset" "$normal" opus '.providers[0].windows[1].resetsAt' '2026-09-12T00:00:00Z'
expect "normal: not locked" "$normal" opus '.providers[0].windows[0].lockedReason' 'null'

expect "locked: status" "$locked" opus '.providers[0].status' 'locked'
expect "locked: reason" "$locked" opus '.providers[0].windows[0].lockedReason' 'usage_limit_reached'

expect "no model: null" "$normal" '' '.providers[0].model' 'null'

expect "failed: status" "$failed" opus '.providers[0].status' 'unknown'
expect "failed: session pct" "$failed" opus '.providers[0].windows[0].percent' 'null'
expect "failed: weekly pct" "$failed" opus '.providers[0].windows[1].percent' 'null'
expect "failed: no reset" "$failed" opus '.providers[0].windows[0].resetsAt' 'null'
expect "failed: still shaped" "$failed" opus '[.providers[0].windows[].id]|join(",")' 'session,weekly'

expect "reshaped: status" "$reshaped" opus '.providers[0].status' 'unknown'
expect "reshaped: session pct" "$reshaped" opus '.providers[0].windows[0].percent' 'null'

expect "array body: status" '[1,2,3]' opus '.providers[0].status' 'unknown'

expect "error body: status" "$errored" opus '.providers[0].status' 'unknown'
expect "error body: pct" "$errored" opus '.providers[0].windows[0].percent' 'null'

expect "zero: status" "$fresh" opus '.providers[0].status' 'ok'
expect "zero: session pct" "$fresh" opus '.providers[0].windows[0].percent' '0'

if [ "$failures" -gt 0 ]; then
    printf '\n%d failed\n' "$failures" >&2
    exit 1
fi

echo
echo "ai-usage.jq: all fixtures pass"
