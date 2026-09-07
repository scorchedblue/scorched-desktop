// System stats: CPU, memory, GPU, disk.
//
// Percentages get a bar, because "is this bad" is answerable at a glance from a
// bar and requires reading from a number. Everything that is not a percentage
// -- temperatures, load, uptime -- is a plain stat row.

import QtQuick

Column {
    spacing: 4

    PanelHeader {
        title: "System"
        subtitle: "up " + Sys.uptimeText + "   load " + Sys.load1.toFixed(2)

        trailing: Icon {
            name: "cpu"
            size: 20
            color: Theme.accent
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    Item {
        width: parent.width
        height: 4
    }

    Gauge {
        width: parent.width
        iconName: "cpu"
        label: "CPU"
        percent: Sys.cpuPercent
        detail: Sys.cpuPercent + "%" + (Sys.cpuTemp > 0 ? "   " + Sys.cpuTemp + "°C" : "")
    }

    Gauge {
        width: parent.width
        iconName: "memory"
        label: "Memory"
        percent: Sys.memPercent
        detail: Sys.memUsedGb.toFixed(1) + " / " + Sys.memTotalGb.toFixed(0) + " GiB"
    }

    Gauge {
        visible: Sys.hasGpu
        width: parent.width
        iconName: "display"
        label: "GPU"
        percent: Sys.gpuPercent
        detail: Sys.gpuPercent + "%" + (Sys.gpuTemp > 0 ? "   " + Sys.gpuTemp + "°C" : "")
    }

    Gauge {
        visible: Sys.hasGpu
        width: parent.width
        iconName: "memory"
        label: "VRAM"
        percent: Sys.gpuMemTotalGb > 0 ? Math.round(Sys.gpuMemUsedGb / Sys.gpuMemTotalGb * 100) : 0
        detail: Sys.gpuMemUsedGb.toFixed(1) + " / " + Sys.gpuMemTotalGb.toFixed(0) + " GiB"
    }

    Gauge {
        width: parent.width
        iconName: "disk"
        label: "Disk"
        percent: Sys.diskPercent
        detail: Sys.diskUsedGb.toFixed(0) + " / " + Sys.diskTotalGb.toFixed(0) + " GiB"
    }

    Item {
        width: parent.width
        height: 6
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    Item {
        width: parent.width
        height: 4
    }

    StatRow {
        visible: Sys.hasGpu
        label: "Graphics"
        value: Sys.gpuName
    }
    StatRow {
        label: "Load (1m)"
        value: Sys.load1.toFixed(2)
    }
    StatRow {
        visible: Sys.swapTotalGb > 0
        label: "Swap"
        value: Sys.swapUsedGb.toFixed(1) + " / " + Sys.swapTotalGb.toFixed(0) + " GiB"
    }
    StatRow {
        label: "Uptime"
        value: Sys.uptimeText
    }
    StatRow {
        // /var, not /: an ostree root is a read-only overlay that always reads
        // 100% full, which is accurate and completely useless.
        label: "Measuring"
        value: "/var"
    }
}
