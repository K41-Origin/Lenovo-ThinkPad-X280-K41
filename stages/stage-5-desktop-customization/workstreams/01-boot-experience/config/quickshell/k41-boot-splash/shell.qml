import Quickshell
import Quickshell.Wayland
import QtQuick

// K41 handoff splash: visual counterpart of the Stage 5 Workstream 1 Plymouth source.
PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "k41-boot-splash"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "#000000"

    readonly property int rectangleCount: 12
    readonly property real ringRadius: 9
    property int phase: 0

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: root.phase = (root.phase + 1) % root.rectangleCount
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2 - 30
        text: "K41"
        color: "#ffffff"
        font.pixelSize: 18
        font.weight: Font.Bold
        font.letterSpacing: 3
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2 + 10
        width: 36
        height: 36

        Repeater {
            model: root.rectangleCount

            delegate: Rectangle {
                required property int index

                width: 4
                height: 10
                color: "transparent"
                border.width: 1
                border.color: "#ffffff"

                x: parent.width / 2 - width / 2
                   + Math.cos(index * 2 * Math.PI / root.rectangleCount) * root.ringRadius
                y: parent.height / 2 - height / 2
                   + Math.sin(index * 2 * Math.PI / root.rectangleCount) * root.ringRadius

                rotation: index * (360 / root.rectangleCount)
                opacity: index === root.phase ? 1.0 : 0.18
            }
        }
    }
}
