import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root
    property real percentage: 0
    property double previousTotal: 0
    property double previousIdle: 0

    function updateFromStat(data) {
        const line = data.trim().split("\n")[0]
        const fields = line.trim().split(/\\s+/)
        if (fields.length < 5 || fields[0] !== "cpu")
            return
        let total = 0
        for (let i = 1; i < fields.length; i++)
            total += Number(fields[i])
        const idle = Number(fields[4]) + (Number(fields[5]) || 0)
        const totalDelta = total - previousTotal
        const idleDelta = idle - previousIdle
        if (previousTotal > 0 && totalDelta > 0)
            percentage = Math.max(0, Math.min(1, (totalDelta - idleDelta) / totalDelta))
        previousTotal = total
        previousIdle = idle
    }

    Process {
        id: reader
        command: ["cat", "/proc/stat"]
        stdout: StdioCollector { onStreamFinished: root.updateFromStat(this.text) }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: if (!reader.running) reader.running = true
    }
    Component.onCompleted: reader.running = true
}