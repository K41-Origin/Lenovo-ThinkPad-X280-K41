import Quickshell
import Quickshell.Io
import QtQuick

// Adapted from caelestia-dots/shell:
// plugin/src/Caelestia/Services/memory.cpp (GPL-3.0).
// Uses the same MemTotal - MemAvailable calculation and exposes normalized
// percentage plus used/total KiB for K41 consumers.
Item {
    id: root
    visible: false
    width: 0
    height: 0

    property real used: 0
    property real total: 0
    readonly property real percentage: total > 0 ? used / total : 0

    function updateFromMeminfo(data) {
        const values = {}
        for (const line of data.trim().split("\n")) {
            const match = line.match(/^(MemTotal|MemAvailable):\s+(\d+)/)
            if (match)
                values[match[1]] = Number(match[2])
        }

        const nextTotal = values.MemTotal
        const available = values.MemAvailable
        if (!Number.isFinite(nextTotal) || !Number.isFinite(available)
                || nextTotal <= 0 || available < 0)
            return

        const nextUsed = Math.max(0, nextTotal - available)
        if (nextTotal === total && nextUsed === used)
            return

        total = nextTotal
        used = nextUsed
    }

    Process {
        id: reader
        command: ["cat", "/proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: root.updateFromMeminfo(this.text)
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: if (!reader.running) reader.running = true
    }

    Component.onCompleted: reader.running = true
}