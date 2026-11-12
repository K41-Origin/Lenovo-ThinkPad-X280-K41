pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

Variants {
    model: Quickshell.screens

    Scope {
        id: scope
        required property ShellScreen modelData

        property real cpuUsage: -1
        property real ramUsage: -1
        property string batteryCapacity: "--"
        property string batteryStatus: "Unknown"
        property date currentTime: new Date()
        property var previousCpu: null
        property bool trayOpen: false

        function updateCpu(): void {
            const line = cpuFile.text().split("\n").find(s => s.startsWith("cpu "));
            if (!line)
                return;
            const values = line.trim().split(/\s+/).slice(1).map(Number);
            if (values.length < 5 || values.some(v => !Number.isFinite(v)))
                return;
            const total = values.reduce((sum, value) => sum + value, 0);
            const idle = values[3] + values[4];
            if (previousCpu !== null) {
                const totalDelta = total - previousCpu.total;
                const idleDelta = idle - previousCpu.idle;
                if (totalDelta > 0)
                    cpuUsage = Math.max(0, Math.min(100, 100 * (1 - idleDelta / totalDelta)));
            }
            previousCpu = { total: total, idle: idle };
        }

        function updateRam(): void {
            const contents = memoryFile.text();
            const totalMatch = contents.match(/^MemTotal:\s+(\d+)\s+kB$/m);
            const availableMatch = contents.match(/^MemAvailable:\s+(\d+)\s+kB$/m);
            if (!totalMatch || !availableMatch)
                return;
            const total = Number(totalMatch[1]);
            const available = Number(availableMatch[1]);
            if (total > 0 && available >= 0 && available <= total)
                ramUsage = 100 * (total - available) / total;
        }

        function updateBattery(): void {
            const capacity = Number(batteryCapacityFile.text().trim());
            batteryCapacity = Number.isFinite(capacity) && capacity >= 0 && capacity <= 100
                ? `${Math.round(capacity)}%` : "--";
            const status = batteryStatusFile.text().trim();
            batteryStatus = status || "Unknown";
        }

        FileView {
            id: cpuFile
            path: "/proc/stat"
            printErrors: false
            onLoaded: scope.updateCpu()
        }

        FileView {
            id: memoryFile
            path: "/proc/meminfo"
            printErrors: false
            onLoaded: scope.updateRam()
        }

        FileView {
            id: batteryCapacityFile
            path: "/sys/class/power_supply/BAT0/capacity"
            printErrors: false
            onLoaded: scope.updateBattery()
        }

        FileView {
            id: batteryStatusFile
            path: "/sys/class/power_supply/BAT0/status"
            printErrors: false
            onLoaded: scope.updateBattery()
        }

        Timer {
            interval: 2000
            running: true
            repeat: true
            onTriggered: {
                cpuFile.reload();
                memoryFile.reload();
            }
        }

        Timer {
            interval: 15000
            running: true
            repeat: true
            onTriggered: {
                batteryCapacityFile.reload();
                batteryStatusFile.reload();
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: scope.currentTime = new Date()
        }

        PanelWindow {
            id: bar
            screen: scope.modelData
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 34
            color: "transparent"
            exclusiveZone: 34
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                color: "#e51b1d27"
                border.width: 1
                border.color: "#35ffffff"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 14

                    Text {
                        text: scope.cpuUsage < 0 ? "CPU --" : `CPU ${Math.round(scope.cpuUsage)}%`
                        color: "#f4f1fa"
                        font.pixelSize: 12
                    }

                    Text {
                        text: scope.ramUsage < 0 ? "RAM --" : `RAM ${Math.round(scope.ramUsage)}%`
                        color: "#f4f1fa"
                        font.pixelSize: 12
                    }

                    Item { Layout.fillWidth: true }

                    Item {
                        implicitWidth: notificationLabel.implicitWidth + 12
                        implicitHeight: parent.height
                        Text {
                            id: notificationLabel
                            anchors.centerIn: parent
                            text: `◉ ${Notifs.notClosed.length}`
                            color: "#f4f1fa"
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: scope.trayOpen = !scope.trayOpen
                        }
                    }

                    Text {
                        text: `Battery ${scope.batteryCapacity} · ${scope.batteryStatus}`
                        color: "#f4f1fa"
                        font.pixelSize: 12
                    }

                    Text {
                        text: Qt.locale().toString(scope.currentTime, "hh:mm  ddd, dd MMM")
                        color: "#f4f1fa"
                        font.pixelSize: 12
                    }
                }
            }
        }

        PanelWindow {
            id: trayWindow
            screen: scope.modelData
            visible: scope.trayOpen
            anchors {
                top: true
                right: true
            }
            implicitWidth: 360
            implicitHeight: 420
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                id: tray
                anchors.fill: parent
                anchors.margins: 8
                radius: 8
                color: "#f01b1d27"
                border.width: 1
                border.color: "#45ffffff"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: `Notifications (${Notifs.notClosed.length})`
                            color: "#f4f1fa"
                            font.pixelSize: 14
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "×"
                            color: "#f4f1fa"
                            font.pixelSize: 20
                        }
                        MouseArea {
                            width: 28
                            height: 28
                            onClicked: scope.trayOpen = false
                        }
                    }

                    ListView {
                        id: notificationList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: Notifs.notClosed

                        delegate: Rectangle {
                            required property var modelData
                            width: notificationList.width
                            height: notificationContent.implicitHeight + 18
                            radius: 6
                            color: "#552f3242"

                            ColumnLayout {
                                id: notificationContent
                                anchors.fill: parent
                                anchors.margins: 9
                                spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: modelData.appName || "Notification"
                                        color: "#aaa6b5"
                                        font.pixelSize: 10
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: "×"
                                        color: "#f4f1fa"
                                        font.pixelSize: 16
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: modelData.close()
                                        }
                                    }
                                }
                                Text {
                                    text: modelData.summary || "(No summary)"
                                    color: "#f4f1fa"
                                    font.pixelSize: 12
                                    font.bold: true
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.body || ""
                                    color: "#d0ccd8"
                                    font.pixelSize: 11
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                }
                            }
                        }
                    }

                    Text {
                        visible: Notifs.notClosed.length === 0
                        text: "No notifications"
                        color: "#aaa6b5"
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
