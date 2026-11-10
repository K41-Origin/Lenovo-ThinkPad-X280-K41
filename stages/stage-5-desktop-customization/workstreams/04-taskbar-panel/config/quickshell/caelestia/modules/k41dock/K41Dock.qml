pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services

Variants {
    model: Screens.screens

    Scope {
        id: scope
        required property ShellScreen modelData

        PanelWindow {
            id: root

            required property ShellScreen screen
            screen: scope.modelData

            anchors {
                bottom: true
                left: true
                right: true
            }

            implicitHeight: 58
            color: "transparent"
            exclusiveZone: 0

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
            readonly property int activeWorkspaceId: monitor?.activeWorkspace?.id ?? 1
            readonly property bool hasFullscreen: monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false

            property bool revealed: false
            property bool triggerHovered: false
            property bool dockHovered: false

            function updateHover(inside: bool, isTrigger: bool): void {
                if (isTrigger)
                    triggerHovered = inside;
                else
                    dockHovered = inside;

                if (inside) {
                    hideTimer.stop();
                    revealed = true;
                } else {
                    hideTimer.restart();
                }
            }

            onHasFullscreenChanged: {
                if (hasFullscreen)
                    revealed = false;
            }

            Timer {
                id: hideTimer
                interval: 550
                repeat: false
                onTriggered: {
                    if (!root.triggerHovered && !root.dockHovered)
                        root.revealed = false;
                }
            }

            // A narrow bottom-edge trigger; it does not reserve an exclusive zone.
            Item {
                id: trigger
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 4
                visible: !root.hasFullscreen

                HoverHandler {
                    onHoveredChanged: root.updateHover(hovered, true)
                }
            }

            Rectangle {
                id: dock

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.revealed && !root.hasFullscreen ? 8 : -(height - 3)

                width: workspaceRow.implicitWidth + 28
                height: 42
                radius: 21
                color: "#e51b1d27"
                border.width: 1
                border.color: "#35ffffff"
                opacity: root.revealed && !root.hasFullscreen ? 1 : 0.08
                visible: !root.hasFullscreen

                Behavior on anchors.bottomMargin {
                    NumberAnimation {
                        duration: 190
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                HoverHandler {
                    onHoveredChanged: root.updateHover(hovered, false)
                }

                Row {
                    id: workspaceRow
                    anchors.centerIn: parent
                    spacing: 9

                    Repeater {
                        model: ScriptModel {
                            values: root.monitor
                                ? Hypr.workspaces.values.filter(w => w.id > 0 && w.monitor === root.monitor)
                                : []
                        }

                        delegate: Item {
                            id: workspaceItem

                            required property var modelData
                            required property int index

                            readonly property bool active: modelData.id === root.activeWorkspaceId
                            readonly property bool occupied: (modelData.lastIpcObject?.windows ?? 0) > 0

                            width: active ? 24 : 14
                            height: 18

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.active ? 22 : 9
                                height: parent.active ? 9 : 9
                                radius: 5
                                color: parent.active ? "#f4f1fa" : parent.occupied ? "#aaa6b5" : "#686573"

                                Behavior on width {
                                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onClicked: Hypr.focusWorkspace(workspaceItem.modelData.id)
                            }

                            ToolTip.visible: false
                        }
                    }
                }
            }
        }
    }
}
