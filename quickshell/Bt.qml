pragma Singleton

// Bluetooth state, via bluetoothctl.
//
// `bluetoothctl show` and `bluetoothctl devices Connected` both work
// non-interactively and need no root, which is why this uses them rather than
// speaking to BlueZ over D-Bus directly.
//
// If no controller is present the indicator hides itself entirely. A
// permanently dead icon teaches people to ignore that corner of the bar.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool available: false
    property bool powered: false
    property string adapterName: ""
    property var devices: []
    property var pairedDevices: []

    // True only in the window between "power was just turned on" and "the
    // next poll knows whether anything actually connected". BlueZ auto-
    // reconnects trusted devices on power-up; without this the icon jumps
    // straight from off to whatever the first poll happens to see, which
    // hides the handshake in between.
    property bool connecting: false

    function refresh() {
        show.running = true;
    }

    function setPowered(on) {
        // Optimistic: flip the state now so the toggle feels immediate, and let
        // the next poll correct it if the controller disagrees.
        root.powered = on;
        root.connecting = on && root.pairedDevices.length > 0;
        toggle.command = ["bluetoothctl", "power", on ? "on" : "off"];
        toggle.running = true;
    }

    function disconnect(mac) {
        toggle.command = ["bluetoothctl", "disconnect", mac];
        toggle.running = true;
    }

    function connect(mac) {
        toggle.command = ["bluetoothctl", "connect", mac];
        toggle.running = true;
    }

    Process {
        id: toggle
        command: ["true"]
    }

    Process {
        id: show
        command: ["bluetoothctl", "show"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text;
                root.available = t.indexOf("Controller") >= 0;
                root.powered = /Powered:\s*yes/.test(t);
                const m = t.match(/Name:\s*(.+)/);
                root.adapterName = m ? m[1].trim() : "";
                if (root.available && root.powered) {
                    connected.running = true;
                    paired.running = true;
                } else {
                    root.devices = [];
                    root.pairedDevices = [];
                    root.connecting = false;
                }
            }
        }
    }

    Process {
        id: connected
        command: ["bluetoothctl", "devices", "Connected"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.trim().split("\n")) {
                    // "Device AA:BB:CC:DD:EE:FF Name With Spaces"
                    const m = line.match(/^Device\s+(\S+)\s+(.*)$/);
                    if (m)
                        out.push({
                            mac: m[1],
                            name: m[2]
                        });
                }
                root.devices = out;
                // Whatever "connecting" meant is resolved now -- either
                // something is connected, or a full poll came back and it
                // still is not.
                root.connecting = false;
            }
        }
    }

    Process {
        id: paired
        command: ["bluetoothctl", "devices", "Paired"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.trim().split("\n")) {
                    const m = line.match(/^Device\s+(\S+)\s+(.*)$/);
                    if (m)
                        out.push({
                            mac: m[1],
                            name: m[2]
                        });
                }
                root.pairedDevices = out;
            }
        }
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
