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

    function refresh() {
        show.running = true;
    }

    function setPowered(on) {
        // Optimistic: flip the state now so the toggle feels immediate, and let
        // the next poll correct it if the controller disagrees.
        root.powered = on;
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
                if (root.available && root.powered)
                    connected.running = true;
                else
                    root.devices = [];
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
