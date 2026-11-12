import Quickshell
import Quickshell.Io
import QtQuick

// Adapted from caelestia-dots/shell:
// plugin/src/Caelestia/Services/cpu.cpp (GPL-3.0).
// Retains Caelestia's /proc/stat delta algorithm; uses a K41-owned QML reader.
QtObject {
    id: root

    property real percentage: 0
    property double previousTotal: 0
    property double previousIdle: 0
    property bool hasSample: false

    function updateFromStat(data) {
        const line = data.trim().split("\n")[0]
        const fields = line.trim().split(/\s+/)
        // Match Caelestia's seven counters: user, nice, system, idle,
        // iowait, irq and softirq. guest counters are already included.
        if (fields.length < 8 || fields[0] !== "cpu")
            return

        let total = 0
        for (let i = 1; i <= 7; i++) {
            const value = Number(fields[i])
            if (!Number.isFinite(value) || value < 0)
                return
            total += value
        }

        const idle = Number(fields[4]) + Number(fields[5])
        if (!Number.isFinite(idle))
            return

        if (hasSample) {
            const totalDelta = total - previousTotal
            const idleDelta = idle - previousIdle
            if (totalDelta > 0) {
                const next = 1 - Math.max(0, idleDelta) / totalDelta
                percentage = Math.max(0, Math.min(1, next))
            }
        }

        previousTotal = total
        previousIdle = idle
        hasSample = true
    }

    Process {
        id: reader
        command: ["cat", "/proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: root.updateFromStat(this.text)
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