pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import Caelestia.Services
import qs.services

Variants {
    model: Quickshell.screens

    Scope {
        id: scope
        required property ShellScreen modelData

        function openNotifications(): void {
            const screenState = ShellState.forScreen(modelData);
            if (screenState)
                screenState.sidebar = true;
        }

        // Start Caelestia's existing ticking services; do not add polling timers.
        ServiceRef {
            service: Cpu
        }

        ServiceRef {
            service: Memory
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
                        text: `CPU ${Math.round(Cpu.percentage * 100)}%`
                        color: "#f4f1fa"
                        font.pixelSize: 12
                    }

                    Text {
                        text: `RAM ${Math.round(Memory.percentage * 100)}%`
                        color: "#f4f1fa"
                        font.pixelSize: 12
                    }

                    Item {
                        Layout.fillWidth: true
                    }

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
                            onClicked: scope.openNotifications()
                        }
                    }

                    Text {
                        text: `Battery ${Math.round(UPower.displayDevice.percentage * 100)}% · ${UPower.onBattery ? "On battery" : "AC"}`
                        color: "#f4f1fa"
                        font.pixelSize: 12
                    }

                    Text {
                        text: Time.format("hh:mm  ddd, dd MMM")
                        color: "#f4f1fa"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
