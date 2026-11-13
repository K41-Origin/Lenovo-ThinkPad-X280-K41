pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../services" as Services

// K41Topbar: K41-owned presentation and service bindings.
Scope {
    // One service instance per loaded Topbar, never one per monitor.
    Services.Notifications { id: notifications }

    Variants {
        model: Quickshell.screens

        Scope {
            id: scope
            required property ShellScreen modelData

            Services.Cpu { id: cpu }
            Services.Memory { id: memory }
            Services.Battery { id: battery }
            Services.Clock { id: clock }
            Services.TopbarState { id: state }

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
                    width: 360
                    height: 320
                    color: "#f01b1d27"
                    border.width: 1
                    border.color: "#55ffffff"
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            width: parent.width
                            Text {
                                text: `Notifications (${notifications.count})`
                                color: "#f4f1fa"
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "Clear all"
                                color: "#c8c5d0"
                                font.pixelSize: 11
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: notifications.clear()
                                }
                            }
                        }

                        Flickable {
                            width: parent.width
                            height: parent.height - 30
                            clip: true
                            contentWidth: width
                            contentHeight: entries.implicitHeight

                            Column {
                                id: entries
                                width: parent.width
                                spacing: 6

                                Repeater {
                                    model: notifications.list
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: entries.width
                                        height: Math.max(72, bodyText.implicitHeight + actionRow.implicitHeight + 34)
                                        radius: 6
                                        color: "#552b2d3a"
                                        border.width: 1
                                        border.color: "#25ffffff"

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 4

                                            RowLayout {
                                                width: parent.width
                                                Text {
                                                    text: modelData.appName
                                                    color: "#bdb8c9"
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: "×"
                                                    color: "#c8c5d0"
                                                    font.pixelSize: 14
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: modelData.close()
                                                    }
                                                }
                                            }

                                            Text {
                                                text: modelData.summary
                                                color: "#f4f1fa"
                                                font.pixelSize: 12
                                                font.bold: true
                                                wrapMode: Text.Wrap
                                                width: parent.width
                                                textFormat: Text.PlainText
                                            }

                                            Text {
                                                id: bodyText
                                                text: modelData.body
                                                color: "#d2ceda"
                                                font.pixelSize: 11
                                                wrapMode: Text.Wrap
                                                width: parent.width
                                                textFormat: Text.PlainText
                                                maximumLineCount: 3
                                                elide: Text.ElideRight
                                            }

                                            Row {
                                                id: actionRow
                                                spacing: 6
                                                Repeater {
                                                    model: modelData.actions
                                                    delegate: Rectangle {
                                                        required property var modelData
                                                        visible: modelData.text !== ""
                                                        width: actionText.implicitWidth + 14
                                                        height: 22
                                                        radius: 4
                                                        color: "#553f4658"
                                                        Text {
                                                            id: actionText
                                                            anchors.centerIn: parent
                                                            text: modelData.text
                                                            color: "#f4f1fa"
                                                            font.pixelSize: 10
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: modelData.invoke()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: notifications.count === 0
                                    text: "No notifications"
                                    color: "#c8c5d0"
                                    font.pixelSize: 12
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: state.closeNotifications()
                    }
                }
            }
        }
    }
}
