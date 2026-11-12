import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root
    property real percentage: 0

    function updateFromMeminfo(data) {
        const values = {}
        for (const line of data.trim().split("\n")) {
            const match = line.match(/^(MemTotal|MemAvailable):\\s+(\\d+)/)
            if (match)
                values[match[1]] = Number(match[2])
        }
        if (values.MemTotal > 0 && values.MemAvailable >= 0)
            percentage = Math.max(0, Math.min(1, 1 - values.MemAvailable / values.MemTotal))
    }

    Process {
        id: reader
        command: ["cat", "/proc/meminfo"]
        stdout: StdioCollector { onStreamFinished: root.updateFromMeminfo(this.text) }
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: if (!reader.running) reader.running = true
    }
    Component.onCompleted: reader.running = true
}