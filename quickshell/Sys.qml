pragma Singleton

// CPU, memory, disk, GPU and temperatures.
//
// Everything comes from one shell invocation on a two second timer. Six
// separate Processes would be six fork/execs and six chances to disagree with
// each other on screen; one keeps every number from the same instant.
//
// CPU utilisation is a rate, not a reading: /proc/stat counts jiffies since
// boot, so it means nothing without a previous sample to subtract. The first
// tick after startup therefore reports 0 rather than a fabricated number.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int cpuPercent: 0
    property real load1: 0
    property int cpuTemp: 0

    property real memUsedGb: 0
    property real memTotalGb: 0
    property int memPercent: 0
    property real swapUsedGb: 0
    property real swapTotalGb: 0

    property real diskUsedGb: 0
    property real diskTotalGb: 0
    property int diskPercent: 0

    property string gpuName: ""
    property int gpuPercent: 0
    property int gpuTemp: 0
    property real gpuMemUsedGb: 0
    property real gpuMemTotalGb: 0
    property bool hasGpu: false

    property int uptimeSeconds: 0

    readonly property string uptimeText: {
        const d = Math.floor(uptimeSeconds / 86400);
        const h = Math.floor((uptimeSeconds % 86400) / 3600);
        const m = Math.floor((uptimeSeconds % 3600) / 60);
        return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m";
    }

    // Previous /proc/stat totals, for the delta.
    property real _prevIdle: -1
    property real _prevTotal: -1

    function refresh() {
        query.running = true;
    }

    Process {
        id: query
        command: ["sh", "-c", "echo '--CPU--'; head -1 /proc/stat; " + "echo '--LOAD--'; cat /proc/loadavg; " + "echo '--MEM--'; grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo; " + "echo '--DISK--'; df -B1 --output=size,used /var 2>/dev/null | tail -n +2; " + "echo '--TEMP--'; for h in /sys/class/hwmon/hwmon*; do " + "  [ \"$(cat $h/name 2>/dev/null)\" = coretemp ] || continue; " + "  for f in $h/temp*_label; do grep -q 'Package id 0' \"$f\" 2>/dev/null && cat \"${f%_label}_input\"; done; " + "done | head -1; " + "echo '--GPU--'; nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null; " + "echo '--UP--'; cut -d. -f1 /proc/uptime"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const sec = {};
                let key = "";
                for (const line of text.split("\n")) {
                    const m = line.match(/^--([A-Z]+)--$/);
                    if (m) {
                        key = m[1];
                        sec[key] = [];
                    } else if (key) {
                        sec[key].push(line);
                    }
                }

                // --- cpu, as a delta ---------------------------------------
                if (sec.CPU && sec.CPU[0]) {
                    const f = sec.CPU[0].trim().split(/\s+/).slice(1).map(Number);
                    if (f.length >= 5) {
                        let total = 0;
                        for (const v of f)
                            total += v;
                        const idle = f[3] + (f[4] || 0);
                        if (root._prevTotal >= 0) {
                            const dt = total - root._prevTotal;
                            const di = idle - root._prevIdle;
                            if (dt > 0)
                                root.cpuPercent = Math.max(0, Math.min(100, Math.round((1 - di / dt) * 100)));
                        }
                        root._prevTotal = total;
                        root._prevIdle = idle;
                    }
                }

                if (sec.LOAD && sec.LOAD[0])
                    root.load1 = parseFloat(sec.LOAD[0].split(" ")[0]) || 0;

                // --- memory ------------------------------------------------
                if (sec.MEM) {
                    const kv = {};
                    for (const l of sec.MEM) {
                        const mm = l.match(/^(\w+):\s+(\d+)/);
                        if (mm)
                            kv[mm[1]] = parseInt(mm[2]);
                    }
                    const toGb = k => (kv[k] || 0) / 1048576;
                    root.memTotalGb = toGb("MemTotal");
                    // MemAvailable, not MemFree: free excludes cache the kernel
                    // will hand back on demand, and reports alarming numbers on
                    // a perfectly healthy machine.
                    root.memUsedGb = root.memTotalGb - toGb("MemAvailable");
                    root.memPercent = root.memTotalGb > 0 ? Math.round(root.memUsedGb / root.memTotalGb * 100) : 0;
                    root.swapTotalGb = toGb("SwapTotal");
                    root.swapUsedGb = root.swapTotalGb - toGb("SwapFree");
                }

                // --- disk --------------------------------------------------
                // /var, not /: the root of an ostree system is a read-only
                // overlay that always reports 100% full, which is true and
                // useless. /var is where anything actually grows.
                if (sec.DISK && sec.DISK[0]) {
                    const d = sec.DISK[0].trim().split(/\s+/).map(Number);
                    if (d.length >= 2) {
                        root.diskTotalGb = d[0] / 1073741824;
                        root.diskUsedGb = d[1] / 1073741824;
                        root.diskPercent = d[0] > 0 ? Math.round(d[1] / d[0] * 100) : 0;
                    }
                }

                if (sec.TEMP && sec.TEMP[0])
                    root.cpuTemp = Math.round((parseInt(sec.TEMP[0]) || 0) / 1000);

                // --- gpu ---------------------------------------------------
                if (sec.GPU && sec.GPU[0] && sec.GPU[0].indexOf(",") > 0) {
                    const g = sec.GPU[0].split(",").map(x => x.trim());
                    root.hasGpu = true;
                    root.gpuName = g[0];
                    root.gpuPercent = parseInt(g[1]) || 0;
                    root.gpuMemUsedGb = (parseInt(g[2]) || 0) / 1024;
                    root.gpuMemTotalGb = (parseInt(g[3]) || 0) / 1024;
                    root.gpuTemp = parseInt(g[4]) || 0;
                } else {
                    root.hasGpu = false;
                }

                if (sec.UP && sec.UP[0])
                    root.uptimeSeconds = parseInt(sec.UP[0]) || 0;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
