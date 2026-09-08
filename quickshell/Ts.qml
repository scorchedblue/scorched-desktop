pragma Singleton

// Tailscale state and actions.
//
// No parsing happens here. quickshell/tailscale.sh reduces `status --json` --
// a document with node keys, byte counters and four timestamps per peer -- to
// the fields this shell binds to, and everything below does is one JSON.parse
// of that. It also runs every state-changing command, so there is one place
// that knows how this shell talks to tailscale. That script is
// `scorched tailscale` waiting to be written; see its header.
//
// Tailscale is the one VPN this shell promotes out of the network badge and
// into its own indicator. Bar.qml says why, and why generic tunnels do not get
// the same treatment.
//
// Polled, not watched. tailscaled does have an event stream, but subscribing
// means holding a long-lived connection to its local API and reimplementing
// reconnection; a five-second poll of a unix socket does not register in `top`.
//
// Logged out is a state, not a failure. The image ships tailscale carrying no
// identity, so "NeedsLogin" -- or "NoState", which is what a daemon that has
// never been authenticated reports -- is the common case on first boot and has
// to read as a machine waiting to be logged in.
//
// WHAT IS HERE, AND WHAT COMES NEXT
//
// The Tailscale surface is landing in five changes rather than one, because one
// pull request carrying all of it would be a review nobody could do:
//
//   1. connection and peers -- this change. up, down, login, logout, switch
//      between accounts, exit nodes, the peer list, ping, and diagnostics.
//   2. Taildrop. Sending is `file cp`; receiving is the part with a design
//      consequence, because `file get` moves files out of an inbox rather than
//      being handed them. A panel that only fetches while it is open strands
//      whatever arrived while it was shut, so the receiver has to be a systemd
//      user unit, not a Process in here.
//   3. Preferences and Tailscale SSH. accept-dns, accept-routes,
//      advertise-exit-node, advertise-routes, shields-up and ssh; and "SSH to
//      this node" from the peer list. --exit-node-allow-lan-access lands with
//      these rather than with the exit nodes below, because its value can only
//      be read once preferences can be read at all, and a toggle that cannot
//      read its own state lies about it.
//   4. serve and funnel, including funnel-active in the indicator -- the one
//      state a user must never fail to notice, because it means a local service
//      is on the public internet.
//   5. Tailnet lock and certificates: status, pending signature requests, and
//      certificate expiry. `lock init` and `lock disable` are deliberately not
//      offered from a status bar.
//
// Diagnostics is in this change rather than a phase of its own: it is a
// question about the connection, and it is two commands and a text pane.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Backend states, as tailscaled names them: NoState, NeedsLogin,
    // NeedsMachineAuth, Stopped, Starting, Running. Not an enum on purpose --
    // this is the daemon's vocabulary, and translating it would only add a
    // second one to keep in step.
    //
    // "Unavailable" is the one addition, and it is not a backend state at all:
    // it means the daemon could not be asked. That has to be distinct from
    // NoState, because a machine nobody has logged in yet wants a login button
    // and a machine whose tailscaled is not running does not -- offering one
    // there would send people round a loop that cannot end.
    //
    // Deliberately not called `state`: QML gives that name a meaning of its own
    // and there is no reason to find out the hard way which one wins.
    property string backendState: "Unavailable"

    property string tsVersion: ""
    property string tailnet: ""
    property string authUrl: ""

    // What tailscaled itself says is wrong, verbatim. It phrases these better
    // than this panel could, and re-wording them would go stale the first time
    // upstream improves one.
    property var health: []

    // Whatever the last command printed. Most of them say nothing when they
    // work, so anything here is worth showing -- above all "Access denied: this
    // operation requires root or operator access", which is what every action
    // returns until `tailscale set --operator` has been run for this user.
    property string lastMessage: ""

    property var selfNode: null
    property var peers: []
    property var exitNode: null
    property var accounts: []

    property string pingTarget: ""
    property string pingResult: ""

    property string diagText: ""

    // The indicator opens a window rather than only a popout, and there is one
    // window for the session. shell.qml owns the instance and binds it to this;
    // the bar, which is per-screen, just sets the flag. See TsWindow.qml.
    property bool windowOpen: false

    readonly property bool available: root.backendState !== "Unavailable"
    readonly property bool online: root.backendState === "Running"
    readonly property bool needsLogin: root.backendState === "NeedsLogin" || root.backendState === "NoState"

    // Has an identity on a tailnet, whether or not the tunnel is currently up.
    // Everything about peers, exit nodes and accounts is gated on this: none of
    // it means anything on a machine that has not joined one.
    readonly property bool loggedIn: root.available && !root.needsLogin
    readonly property bool viaExitNode: !!root.exitNode

    readonly property var exitNodeOptions: root.peers.filter(p => p.offersExit)

    // One phrasing of the state for the whole shell. The bar, the popout and
    // the window all read this, so they cannot end up describing the same
    // machine three different ways.
    readonly property string summary: root.backendState === "Running" ? (root.viaExitNode ? "Connected via " + root.exitNode.host : "Connected") : root.backendState === "Starting" ? "Connecting" : root.backendState === "Stopped" ? "Stopped" : root.backendState === "NeedsMachineAuth" ? "Waiting for approval" : root.needsLogin ? "Not logged in" : "tailscaled not reachable"

    // Spawned through bash rather than executed directly, the same way every
    // other helper in this shell is: the file's mode then stops mattering, and
    // rsync'ing the config to a VM cannot break the shell by losing it.
    readonly property string _script: Quickshell.env("HOME") + "/.config/quickshell/tailscale.sh"

    function _cmd(args) {
        return ["bash", root._script].concat(args);
    }

    function refresh() {
        statusProc.running = true;
    }

    // Nothing was read, so nothing is known. Everything the last successful
    // poll left behind goes with it -- a tailnet name still on screen after the
    // daemon has gone is worse than an empty panel, because it reads as current.
    function _clear(message) {
        root.backendState = "Unavailable";
        root.lastMessage = message;
        root.tsVersion = "";
        root.tailnet = "";
        root.authUrl = "";
        root.health = [];
        root.selfNode = null;
        root.peers = [];
        root.exitNode = null;
    }

    function refreshAccounts() {
        accountsProc.running = true;
    }

    function showWindow() {
        // Accounts are only read when the window opens. `switch --list` is a
        // second process and nothing outside that window shows its answer.
        root.refreshAccounts();
        root.windowOpen = true;
    }

    function hideWindow() {
        root.windowOpen = false;
    }

    // --- actions ------------------------------------------------------------
    //
    // Two processes, not one. `up` and `login` block until the machine has been
    // authenticated, which can be minutes, and a Process that is already
    // running silently drops a second `running = true`. Sharing one would mean
    // that starting a login makes every other button stop working.

    function bringUp() {
        root.lastMessage = "";
        session.command = root._cmd(["run", "up"]);
        session.running = true;
    }

    function login() {
        root.lastMessage = "";
        session.command = root._cmd(["run", "login"]);
        session.running = true;
    }

    function _act(args) {
        root.lastMessage = "";
        action.command = root._cmd(["run"].concat(args));
        action.running = true;
    }

    function bringDown() {
        root._act(["down"]);
    }

    function logout() {
        root._act(["logout"]);
    }

    function switchAccount(account) {
        root._act(["switch", account]);
    }

    // An empty value clears the exit node; that is tailscale's own convention
    // for the flag, not an accident of building the string.
    function setExitNode(addr) {
        root._act(["set", "--exit-node=" + addr]);
    }

    function clearExitNode() {
        root.setExitNode("");
    }

    function ping(addr) {
        root.pingTarget = addr;
        root.pingResult = "pinging...";
        pingProc.command = root._cmd(["ping", addr]);
        pingProc.running = true;
    }

    function runDiagnostics() {
        root.diagText = "running...";
        diagProc.running = true;
    }

    // --- processes ----------------------------------------------------------

    Process {
        id: statusProc
        command: root._cmd(["status"])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let d = null;
                try {
                    d = JSON.parse(text);
                } catch (e) {
                    // The script promises one JSON object on every path, so
                    // this only fires if it is missing or has been replaced.
                    root._clear("could not read tailscale state");
                    return;
                }

                if (!d.ok) {
                    root._clear(d.error || "");
                    return;
                }

                root.backendState = d.state;
                root.tsVersion = d.version;
                root.tailnet = d.tailnet;
                root.authUrl = d.authUrl;
                root.health = d.health;
                root.selfNode = d.self;
                root.peers = d.peers;
                root.exitNode = d.exitNode;
            }
        }
    }

    Process {
        id: accountsProc
        command: root._cmd(["accounts"])
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.accounts = d.ok ? d.accounts : [];
                } catch (e) {
                    root.accounts = [];
                }
            }
        }
    }

    // Short commands: down, logout, switch, set.
    Process {
        id: action
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.lastMessage = text.trim();
                settle.restart();
            }
        }
    }

    // Long ones: up and login, which do not return until the node is
    // authenticated. The auth URL is not read from here -- it arrives in
    // `status` as AuthURL, which is available immediately, whereas this stream
    // does not close until the flow is finished one way or the other.
    Process {
        id: session
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.lastMessage = text.trim();
                settle.restart();
            }
        }
    }

    Process {
        id: pingProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                // `ping` retries until the connection is direct, printing a
                // line each time. The last one is the current answer; the
                // earlier ones are the path it took to get there.
                const lines = text.trim().split("\n").filter(l => l.trim() !== "");
                root.pingResult = lines.length > 0 ? lines[lines.length - 1] : "no reply";
            }
        }
    }

    Process {
        id: diagProc
        command: root._cmd(["diag"])
        stdout: StdioCollector {
            onStreamFinished: root.diagText = text.trim()
        }
    }

    // A command changes state the poll would not see for up to five seconds,
    // which is long enough for a click to feel like it did nothing.
    Timer {
        id: settle
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
