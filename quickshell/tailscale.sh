#!/usr/bin/bash
#
# Tailscale state for the shell, reduced to the fields the UI binds to.
#
#   tailscale.sh status      # one JSON object: backend state, self, peers
#   tailscale.sh accounts    # one JSON object: the accounts `switch` knows
#   tailscale.sh diag        # plain text: `tailscale status` then `netcheck`
#   tailscale.sh ping PEER   # plain text: what `tailscale ping` printed
#   tailscale.sh run ARGS... # run `tailscale ARGS...`, print what it said
#
# `tailscale status --json` is a large document. Every peer carries node keys,
# byte counters, capability lists and four separate timestamps, none of which
# this bar will ever show. Handing that to QML would put a real parser in the
# shell, so this emits one small object instead and the QML side does a single
# JSON.parse with no field-picking.
#
# Interim by design. This is `scorched tailscale` waiting to be written, the
# same way apps.sh is `scorched apps` -- see scorched-tools. The shape below is
# the contract that subcommand has to keep.
#
# The JSON paths always print exactly one object and exit 0, including when
# tailscaled is down or the binary is missing. The alternative is a UI that has
# to tell "no output" from "not JSON" from "an error on stdout", and the
# logged-out case -- the common one, since the image ships tailscale carrying no
# identity -- would arrive as an error rather than as a state.
#
# `set -e` is deliberately absent, and so is any check of tailscale's exit
# status: `tailscale status` exits non-zero whenever the backend is not running,
# which includes being logged out. A failure here is a result to report, not a
# reason to die silently, and "not logged in" is not a failure at all.

set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
    printf '{"ok":false,"error":"jq is not installed"}\n'
    exit 0
fi

emit_error() {
    jq -nc --arg message "$1" '{ok: false, error: $message}'
}

if ! command -v tailscale >/dev/null 2>&1; then
    emit_error "tailscale is not installed"
    exit 0
fi

# One shape for self and for every peer, so the UI has a single row type.
#
# `direct` is the question worth answering about a peer: CurAddr is set only
# once the connection is peer-to-peer, so an empty one means the traffic is
# going through a DERP relay and `relay` names which.
#
# `ip` prefers the IPv4 address because that is the one people recognise and the
# one `set --exit-node` is given. The IPv6 is dropped rather than shown.
readonly NODE='
    def node:
      {
        id:         (.ID // ""),
        host:       (.HostName // ""),
        dns:        ((.DNSName // "") | sub("\\.$"; "")),
        os:         (.OS // ""),
        ip:         (((.TailscaleIPs // []) | map(select(contains(":") | not)) | first) // ""),
        online:     (.Online // false),
        active:     (.Active // false),
        relay:      (.Relay // ""),
        direct:     (((.CurAddr // "") | length) > 0),
        offersExit: (.ExitNodeOption // false),
        isExit:     (.ExitNode // false)
      };
'

# Health is a list of strings the daemon wants a human to read. It is passed
# through verbatim rather than interpreted: tailscaled already phrases these
# better than the panel could, and reinterpreting them would go stale.
readonly STATUS_FILTER="$NODE"'
    {
      ok:       true,
      state:    (.BackendState // "NoState"),
      authUrl:  (.AuthURL // ""),
      version:  (.Version // ""),
      tailnet:  (.CurrentTailnet.Name // ""),
      health:   (if ((.Health // null) | type) == "array" then .Health else [] end),
      self:     (if (.Self // null) == null then null else (.Self | node) end),
      peers:    ((.Peer // {}) | to_entries | map(.value | node) | sort_by(.host)),
      exitNode: ((.Peer // {}) | to_entries | map(.value)
                 | map(select(.ExitNode == true) | node) | first)
    }
'

# The exit status is deliberately ignored, here and in accounts().
# `tailscale status` exits non-zero whenever the backend is not running, and
# that includes the logged-out case -- which is a state this shell has to show
# cleanly, not an error. Whether there is usable JSON on stdout is the real
# question, so that is the question asked.
#
# stderr is discarded rather than folded in: anything it says would land in the
# middle of the document and turn a readable state into a parse failure.
status() {
    local raw
    raw=$(tailscale status --json 2>/dev/null)
    if ! printf '%s' "$raw" | jq -c "$STATUS_FILTER" 2>/dev/null; then
        emit_error "could not reach tailscaled"
    fi
}

accounts() {
    local raw
    raw=$(tailscale switch --list 2>/dev/null)
    # `switch --list` prints a table rather than JSON: an ID, a tailnet, an
    # account, and a trailing "*" on the one in use. Parsed leniently on
    # purpose -- if those columns ever move, or there are no accounts at all,
    # this yields an empty list rather than nonsense, and an empty list simply
    # hides the section.
    printf '%s\n' "$raw" |
        awk '$1 != "ID" && NF >= 3 {
            printf "%s\t%s\t%s\t%s\n", $1, $2, $3, ($NF == "*" ? "true" : "false")
        }' |
        jq -Rsc 'split("\n")
                 | map(select(length > 0) | split("\t"))
                 | map({id: .[0], tailnet: .[1], account: .[2], current: (.[3] == "true")})
                 | {ok: true, accounts: .}'
}

# Text, not JSON. `status` and `netcheck` explain a bad connection better than
# anything this panel could infer from the same data, so their output is shown
# as they wrote it rather than re-rendered.
diag() {
    printf '=== tailscale status ===\n'
    tailscale status 2>&1
    printf '\n=== tailscale netcheck ===\n'
    tailscale netcheck 2>&1
    printf '\n'
}

# Every state-changing call goes through here rather than being spelled out in
# QML, so there is one place that knows how this shell talks to tailscale.
#
# stderr is folded into stdout here, unlike in status(): most of these say
# nothing at all when they work, and the one thing they do say when they fail is
# exactly what the panel has to show -- notably "Access denied: this operation
# requires root or operator access", which is what every one of them returns
# until `tailscale set --operator` has been run for this user.
#
# The trailing newline on this and on ping_peer() and diag() is load-bearing:
# Quickshell's StdioCollector does not fire onStreamFinished on a completely
# empty stream, so a command that printed nothing would leave the caller waiting
# for a callback that never comes.
run_cmd() {
    if [ "$#" -eq 0 ]; then
        printf 'no command given\n'
        return
    fi
    tailscale "$@" 2>&1
    printf '\n'
}

ping_peer() {
    local target="${1:-}"
    if [ -z "$target" ]; then
        printf 'no peer given\n'
        return
    fi
    tailscale ping "$target" 2>&1
    printf '\n'
}

case "${1:-status}" in
    status)
        status
        ;;
    accounts)
        accounts
        ;;
    diag)
        diag
        ;;
    ping)
        ping_peer "${2:-}"
        ;;
    run)
        shift
        run_cmd "$@"
        ;;
    *)
        echo "usage: tailscale.sh status|accounts|diag|ping PEER|run ARGS..." >&2
        exit 2
        ;;
esac
