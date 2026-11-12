pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// K41Topbar: K41-owned presentation and service bindings.
Variants {
    model: Quickshell.screens

    Scope {
        id: scope
        required property ShellScreen modelData

        Cpu { id: cpu }
        Memory { id: memory }
        Battery { id: battery }
        Clock { id: clock }
        Notifications { id: notifications }
        TopbarState { id: state }

        PanelWindow {
            id: bar
            screen: scope.modelData
            anchors { top: true; left: true; right: true }
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

                    Text { text: `CPU ${Math.round(cpu.percentage * 100)}%`; color: "#f4f1fa"; font.pixelSize: 12 }
                    Text { text: `RAM ${Math.round(memory.percentage * 100)}%`; color: "#f4f1fa"; font.pixelSize: 12 }
                    Item { Layout.fillWidth: true }

                    Item {
                        implicitWidth: notificationLabel.implicitWidth + 12
                        implicitHeight: parent.height
                        Text {
                            id: notificationLabel
                            anchors.centerIn: parent
                            text: `◉ ${notifications.count}`
                            color: "#f4f1fa"
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: state.toggleNotifications()
                        }
                    }

                    Text {
                        text: battery.available
                              ? `Battery ${Math.round(battery.percentage * 100)}% · ${battery.onBattery ? "On battery" : "AC"}`
                              : "Battery N/A"
                        color: "#f4f1fa"
                        font.pixelSize: 12
                    }
                    Text { text: clock.text; color: "#f4f1fa"; font.pixelSize: 12 }
                }
            }

            Rectangle {
                visible: state.notificationPanelOpen
                anchors.top: parent.bottom
                anchors.right: parent.right
                width: 320
                height: 76
                color: "#f01b1d27"
                border.width: 1
                border.color: "#35ffffff"
                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6
                    Text { text: "K41 Notifications"; color: "#f4f1fa"; font.bold: true }
                    Text {
                        text: notifications.status
                        color: "#c8c5d0"
                        wrapMode: Text.WordWrap
                        width: parent.width
                        font.pixelSize: 11
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: state.closeNotifications()
                }
            }
        }
    }
}